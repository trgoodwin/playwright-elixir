# Catalog ETS Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Catalog GenServer-backed map with an ETS table so reads bypass the GenServer entirely, eliminating serialization on the hot path.

**Architecture:** ETS table (`:set`, `:public`, `read_concurrency: true`) stores all Playwright objects. The Catalog GenServer remains as a thin coordinator for `awaiting` (blocking until an object is created) and `watchers` (blocking until a predicate is satisfied). Reads (`get` of existing items, `list`, `all`, `rm`) go directly to ETS. Writes (`put`) insert into ETS then cast to GenServer to notify blocked callers.

**Tech Stack:** Elixir, ETS, GenServer, `:persistent_term`

---

### Task 1: Rewrite Catalog internals — ETS storage, GenServer for awaiting/watchers

**Files:**
- Modify: `lib/playwright/sdk/channel/catalog.ex`

**Step 1: Rewrite `init/1` to create an ETS table**

Replace the current init:

```elixir
@impl GenServer
def init(root) do
  Process.flag(:trap_exit, true)

  table = :ets.new(:catalog, [:set, :public, {:read_concurrency, true}])
  :ets.insert(table, {"Root", root})

  {:ok,
   %__MODULE__{
     awaiting: %{},
     table: table,
     watchers: []
   }}
end
```

Update the struct to replace `:storage` with `:table`:

```elixir
defstruct [:awaiting, :table, watchers: []]
```

**Step 2: Add `table/1` accessor for callers to get the ETS ref**

```elixir
def table(catalog) do
  GenServer.call(catalog, :table)
end
```

And the handle_call:

```elixir
@impl GenServer
def handle_call(:table, _, %{table: table} = state) do
  {:reply, table, state}
end
```

This is only used once during Session init to store in persistent_term — not on the hot path.

**Step 3: Rewrite `get/3` — ETS-first, GenServer fallback**

```elixir
@spec get(pid() | :ets.table(), binary(), map()) :: struct() | {:error, Channel.Error.t()}
def get(table, guid, options \\ %{}) when is_reference(table) do
  case :ets.lookup(table, guid) do
    [{^guid, item}] ->
      item

    [] ->
      with_timeout(options, fn timeout ->
        GenServer.call(:ets.info(table, :owner), {:await, guid}, timeout)
      end)
  end
end
```

The GenServer fallback uses `:ets.info(table, :owner)` to derive the GenServer PID from the table ref. Alternatively, callers can pass the PID explicitly — but this keeps the API surface small.

**Important:** The GenServer's `handle_call(:await, ...)` must re-check ETS (race guard):

```elixir
@impl GenServer
def handle_call({:await, guid}, from, %{awaiting: awaiting, table: table} = state) do
  case :ets.lookup(table, guid) do
    [{^guid, item}] ->
      {:reply, item, state}

    [] ->
      {:noreply, %{state | awaiting: Map.put(awaiting, guid, from)}}
  end
end
```

**Step 4: Rewrite `put/2` — ETS insert, then cast to GenServer for notifications**

```elixir
@spec put(pid(), struct()) :: struct()
def put(catalog, %{guid: guid} = resource) do
  table = :sys.get_state(catalog).table
  :ets.insert(table, {guid, resource})
  GenServer.cast(catalog, {:notify, guid, resource})
  resource
end
```

Wait — we can't use `:sys.get_state` on the hot path. The `put` caller needs access to both the ETS table (to insert) and the GenServer PID (to notify). Since `put` is called from `Channel.patch` and `Response.recv`, the caller always has both via `Session.catalog(session)` (PID) and the new `catalog_table` in persistent_term.

Revised approach: `put` takes both the table and the catalog PID:

```elixir
@spec put(:ets.table(), pid(), struct()) :: struct()
def put(table, catalog, %{guid: guid} = resource) do
  :ets.insert(table, {guid, resource})
  GenServer.cast(catalog, {:notify, guid, resource})
  resource
end
```

The GenServer handles notification:

```elixir
@impl GenServer
def handle_cast({:notify, guid, item}, %{awaiting: awaiting, watchers: watchers} = state) do
  {caller, awaiting} = Map.pop(awaiting, guid)

  if caller do
    GenServer.reply(caller, item)
  end

  {matched, remaining} =
    Enum.split_with(watchers, fn {watcher_guid, predicate, _from} ->
      watcher_guid == guid && predicate.(item)
    end)

  Enum.each(matched, fn {_guid, _predicate, from} ->
    GenServer.reply(from, item)
  end)

  {:noreply, %{state | awaiting: awaiting, watchers: remaining}}
end
```

**Step 5: Rewrite `list/2` — direct ETS read**

```elixir
@spec list(:ets.table(), map()) :: [struct()]
def list(table, filter) when is_reference(table) do
  items =
    :ets.tab2list(table)
    |> Enum.map(fn {_guid, item} -> item end)

  filter(items, normalize_parent(filter), [])
end
```

The `filter/3` and `normalize_parent/1` private functions stay unchanged.

**Step 6: Rewrite `all/1` — direct ETS read**

```elixir
def all(table) when is_reference(table) do
  :ets.tab2list(table) |> Map.new()
end
```

**Step 7: Rewrite `rm/2` and `rm_r/3` — direct ETS delete**

```elixir
defp rm(table, guid) when is_reference(table) do
  :ets.delete(table, guid)
  :ok
end

@spec rm_r(:ets.table(), binary(), pid() | nil) :: :ok
def rm_r(table, guid, session \\ nil) when is_reference(table) do
  case :ets.lookup(table, guid) do
    [{^guid, item}] ->
      children = list(table, %{parent: item})
      Enum.each(children, fn child -> rm_r(table, child.guid, session) end)
      if session, do: Channel.Session.unbind_all(session, guid)
      rm(table, guid)

    [] ->
      :ok
  end
end
```

Note: `rm_r` previously called `get(catalog, guid)` to get the parent struct for filtering children. Now it does a direct `:ets.lookup`.

**Step 8: Rewrite `watch/4` — GenServer call (unchanged pattern)**

```elixir
@spec watch(pid(), binary(), (struct() -> boolean()), map()) :: struct() | {:error, Channel.Error.t()}
def watch(catalog, guid, predicate, options \\ %{}) do
  with_timeout(options, fn timeout ->
    GenServer.call(catalog, {:watch, guid, predicate}, timeout)
  end)
end
```

The GenServer handler must read from ETS instead of state:

```elixir
@impl GenServer
def handle_call({:watch, guid, predicate}, from, %{table: table, watchers: watchers} = state) do
  case :ets.lookup(table, guid) do
    [{^guid, item}] when predicate.(item) == true ->
      {:reply, item, state}

    _ ->
      {:noreply, %{state | watchers: [{guid, predicate, from} | watchers]}}
  end
end
```

Wait — using `predicate.(item)` in a guard doesn't work (guards can't call arbitrary functions). Revised:

```elixir
@impl GenServer
def handle_call({:watch, guid, predicate}, from, %{table: table, watchers: watchers} = state) do
  item =
    case :ets.lookup(table, guid) do
      [{^guid, found}] -> found
      [] -> nil
    end

  if item && predicate.(item) do
    {:reply, item, state}
  else
    {:noreply, %{state | watchers: [{guid, predicate, from} | watchers]}}
  end
end
```

**Step 9: Update `terminate/2`**

No change needed — it already iterates awaiting and watchers. The ETS table is automatically destroyed when the owning process dies.

**Step 10: Remove dead `handle_call` clauses**

Remove these GenServer callbacks that are no longer used:
- `handle_call(:all, ...)`
- `handle_call({:get, ...}, ...)`
- `handle_call({:list, ...}, ...)`
- `handle_call({:put, ...}, ...)`
- `handle_call({:rm, ...}, ...)`

**Step 11: Compile and verify**

Run: `mix compile --warnings-as-errors`
Expected: Compilation errors from callers using the old API (this is expected — Task 2 fixes them)

**Step 12: Commit**

```bash
git add lib/playwright/sdk/channel/catalog.ex
git commit -m "Rewrite Catalog internals to use ETS for storage

ETS table (:set, :public, read_concurrency: true) replaces the
GenServer-backed map. get/list/all/rm go directly to ETS. put writes
to ETS then casts to GenServer to notify awaiting/watcher callers.
GenServer remains only for blocking coordination patterns."
```

---

### Task 2: Store ETS table ref in persistent_term and update Session

**Files:**
- Modify: `lib/playwright/sdk/channel/session.ex`

**Step 1: Store `catalog_table` in persistent_term**

In `Session.init/1`, after the Supervisor starts and `children_map` is built, get the ETS table ref from the Catalog GenServer and add it to the persistent_term map:

```elixir
catalog_pid = children_map[Channel.Catalog]
catalog_table = Channel.Catalog.table(catalog_pid)

:persistent_term.put({__MODULE__, pid}, %{
  catalog: catalog_pid,
  catalog_table: catalog_table,
  connection: children_map[Channel.Connection],
  task_supervisor: children_map[:task_supervisor]
})
```

**Step 2: Add `catalog_table/1` accessor**

```elixir
def catalog_table(session) do
  :persistent_term.get({__MODULE__, session}).catalog_table
end
```

**Step 3: Compile and verify**

Run: `mix compile --warnings-as-errors`

**Step 4: Commit**

```bash
git add lib/playwright/sdk/channel/session.ex
git commit -m "Store Catalog ETS table ref in persistent_term

Session.catalog_table/1 provides lock-free access to the ETS table
for direct reads, bypassing the Catalog GenServer entirely."
```

---

### Task 3: Update Channel module to use ETS table

**Files:**
- Modify: `lib/playwright/sdk/channel.ex`

**Step 1: Update `find/3` to use ETS table directly**

```elixir
def find(session, {:guid, guid}, options \\ %{}) when is_binary(guid) do
  Session.catalog_table(session) |> Catalog.get(guid, options)
end
```

**Step 2: Update `list/3` to use ETS table directly**

```elixir
def list(session, {:guid, guid}, type) do
  Catalog.list(Session.catalog_table(session), %{
    parent: guid,
    type: type
  })
end
```

**Step 3: Update `patch/3` to use both table and PID**

```elixir
def patch(session, {:guid, guid}, data) when is_binary(guid) do
  table = Session.catalog_table(session)
  catalog = Session.catalog(session)
  owner = Catalog.get(table, guid)
  Catalog.put(table, catalog, Map.merge(owner, data))
end
```

**Step 4: Update `load_preview` to use catalog PID for `watch`**

`watch` still needs the GenServer PID (it's a blocking call). No change needed here — `Session.catalog(session)` already returns the PID.

**Step 5: Compile and verify**

Run: `mix compile --warnings-as-errors`

**Step 6: Commit**

```bash
git add lib/playwright/sdk/channel.ex
git commit -m "Update Channel to use Catalog ETS table for reads

find/3 and list/3 now read directly from ETS. patch/3 passes both
table and PID to Catalog.put for write + notification."
```

---

### Task 4: Update Response module to use ETS table

**Files:**
- Modify: `lib/playwright/sdk/channel/response.ex`

**Step 1: Update all `recv` clauses**

Each `recv` clause currently does `catalog = Channel.Session.catalog(session)` then uses `catalog` (the PID) for both reads and writes. Split into table (reads) and PID (writes):

For `__create__`:
```elixir
def recv(session, %{guid: guid, method: "__create__", params: %{guid: _} = params}) when is_binary(guid) do
  table = Channel.Session.catalog_table(session)
  catalog = Channel.Session.catalog(session)
  parent = (guid == "" && "Root") || guid

  {:ok, owner} = ChannelOwner.from(params, Channel.Catalog.get(table, parent))
  Channel.Catalog.put(table, catalog, owner)
end
```

For `__dispose__`:
```elixir
def recv(session, %{guid: guid, method: "__dispose__"}) when is_binary(guid) do
  table = Channel.Session.catalog_table(session)
  Channel.Catalog.rm_r(table, guid, session)
end
```

For events:
```elixir
def recv(session, %{guid: guid, method: method, params: params}) when is_binary(guid) do
  table = Channel.Session.catalog_table(session)
  owner = Channel.Catalog.get(table, guid)
  event = Channel.Event.new(owner, method, params, table)
  resolve(session, table, owner, event)
end
```

For command responses:
```elixir
def recv(session, %{id: _} = message) do
  table = Channel.Session.catalog_table(session)
  build(message, table)
end
```

**Step 2: Update `resolve/4` — `put` needs both table and PID**

```elixir
defp resolve(session, table, owner, event) do
  bindings = Map.get(Channel.Session.bindings(session), {owner.guid, event.type}, [])

  resolved =
    Enum.reduce(bindings, event, fn callback, acc ->
      case callback.(acc) do
        {:patch, owner} ->
          Map.put(acc, :target, owner)

        _ok ->
          acc
      end
    end)

  catalog = Channel.Session.catalog(session)
  Channel.Catalog.put(table, catalog, resolved.target)

  async_bindings = Map.get(Channel.Session.async_bindings(session), {owner.guid, event.type}, [])

  if async_bindings != [] do
    task_supervisor = Channel.Session.task_supervisor(session)

    Enum.each(async_bindings, fn callback ->
      Task.Supervisor.start_child(task_supervisor, fn -> callback.(resolved) end)
    end)
  end

  resolved
end
```

**Step 3: Update all `parse` clauses**

The `parse` functions receive `catalog` which is currently a PID. They only do reads (`Catalog.get`), so they should receive the ETS table instead. No signature changes needed since the variable name `catalog` is reused — just the type changes from PID to table ref. All `Channel.Catalog.get(catalog, guid)` calls will now receive the table ref, which matches the new `get/3` API.

**Step 4: Compile and verify**

Run: `mix compile --warnings-as-errors`

**Step 5: Commit**

```bash
git add lib/playwright/sdk/channel/response.ex
git commit -m "Update Response to use Catalog ETS table for reads

__create__, __dispose__, event, and command response handlers now
read directly from ETS. put calls pass both table and PID."
```

---

### Task 5: Update Event module to use ETS table

**Files:**
- Modify: `lib/playwright/sdk/channel/event.ex`

**Step 1: No API change needed**

`Event.new/4` receives `catalog` as the 4th argument. It's used in `hydrate/2` which calls `Channel.Catalog.get(catalog, guid)`. Since `Catalog.get` now takes a table ref instead of a PID, and callers already pass the table ref (after Task 4), this works without changes.

Verify by reading the call site in `response.ex` — after Task 4, it passes `table` to `Event.new(owner, method, params, table)`.

**Step 2: Compile and verify**

Run: `mix compile --warnings-as-errors`

---

### Task 6: Update caller modules (Route, Page, BrowserContext, Locator, Frame)

**Files:**
- Modify: `lib/playwright/route.ex`
- Modify: `lib/playwright/page.ex`
- Modify: `lib/playwright/browser_context.ex`
- Modify: `lib/playwright/locator.ex`
- Modify: `lib/playwright/frame.ex`

**Step 1: Update `route.ex` — 5 call sites**

All 5 Route functions do the same pattern:
```elixir
catalog = Channel.Session.catalog(session)
request = Channel.Catalog.get(catalog, route.request.guid)
```

Change to:
```elixir
table = Channel.Session.catalog_table(session)
request = Channel.Catalog.get(table, route.request.guid)
```

Apply to: `abort/2` (line 18-19), `continue/2` (line 32-33), `fallback/2` (line 44-45), `fetch/2` (line 57-58), `fulfill/2` (line 81-82).

**Step 2: Update `page.ex` — `on_route/2`**

```elixir
defp on_route(page, %{params: %{route: %{request: request} = route} = _params} = _event) do
  Enum.reduce_while(page.routes, [], fn handler, acc ->
    table = Channel.Session.catalog_table(page.session)
    request = Channel.Catalog.get(table, request.guid)
    ...
```

**Step 3: Update `browser_context.ex` — `on_route/2`**

Same pattern as page.ex:
```elixir
table = Channel.Session.catalog_table(context.session)
request = Channel.Catalog.get(table, request.guid)
```

**Step 4: Update `locator.ex` — `find_page_for_frame/1`**

```elixir
defp find_page_for_frame(%Frame{} = frame) do
  alias Playwright.SDK.Channel.{Catalog, Session}

  table = Session.catalog_table(frame.session)

  table
  |> Catalog.all()
  |> Map.values()
  |> Enum.find(fn
    %Page{} = p -> p.main_frame && p.main_frame.guid == frame.guid
    _ -> false
  end)
end
```

**Step 5: Update `frame.ex` — `do_wait_for_url/4`**

`frame.ex` uses `Catalog.watch` which still takes the GenServer PID. Verify the call site:

```elixir
catalog = Channel.Session.catalog(session)
case Channel.Catalog.watch(catalog, frame.guid, ...) do
```

This stays unchanged — `watch` still requires the GenServer PID.

**Step 6: Compile and verify**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation

**Step 7: Commit**

```bash
git add lib/playwright/route.ex lib/playwright/page.ex lib/playwright/browser_context.ex lib/playwright/locator.ex lib/playwright/frame.ex
git commit -m "Update Route, Page, BrowserContext, Locator to use Catalog ETS reads

All Catalog.get and Catalog.list calls in these modules now use the
ETS table ref via Session.catalog_table instead of the GenServer PID."
```

---

### Task 7: Update Catalog unit tests

**Files:**
- Modify: `test/sdk/channel/catalog_test.exs`

**Step 1: Update test setup**

The tests currently use `catalog` (the PID) for everything. Now reads need the ETS table ref, writes need the PID. Update setup:

```elixir
setup do
  catalog = start_supervised!({Catalog, %{guid: "Root"}})
  table = Catalog.table(catalog)
  %{catalog: catalog, table: table}
end
```

**Step 2: Update `get` tests**

```elixir
describe "Catalog.get/2" do
  test "returns an existing resource by `param: guid`", %{table: table} do
    assert Catalog.get(table, "Root") == %{guid: "Root"}
  end

  test "returns an awaited resource by `param: guid`", %{catalog: catalog, table: table} do
    Task.start(fn ->
      :timer.sleep(100)
      Catalog.put(table, catalog, %{guid: "Addition"})
    end)

    assert Catalog.get(table, "Addition") == %{guid: "Addition"}
  end

  test "returns an Error when there is no match within the timeout period", %{table: table} do
    assert {:error, %Error{message: "Timeout 50ms exceeded."}} = Catalog.get(table, "Missing", %{timeout: 50})
  end
end
```

**Step 3: Update `list` tests**

Change `Catalog.list(catalog, filter)` to `Catalog.list(table, filter)`.
Change `Catalog.put(catalog, resource)` to `Catalog.put(table, catalog, resource)`.
Change `Catalog.get(catalog, guid)` to `Catalog.get(table, guid)`.

**Step 4: Update `put` tests**

```elixir
describe "Catalog.put/2" do
  test "adds a resource to the catalog", %{catalog: catalog, table: table} do
    resource = %{guid: "Addition"}
    assert ^resource = Catalog.put(table, catalog, resource)
    assert ^resource = Catalog.get(table, "Addition")
  end
end
```

**Step 5: Update `terminate` tests**

The `Catalog.get` and `Catalog.watch` calls in terminate tests need updated:
- `Catalog.get(catalog, "NonExistent", ...)` → `Catalog.get(table, "NonExistent", ...)`
- `Catalog.put(catalog, ...)` → `Catalog.put(table, catalog, ...)`
- `Catalog.watch(catalog, ...)` stays as-is (still takes PID)

**Step 6: Update `rm_r` test**

```elixir
describe "Catalog.rm_r/2" do
  test "removes a resource and its descendants", %{catalog: catalog, table: table} do
    Catalog.put(table, catalog, %{guid: "Trunk", parent: %{guid: "Root"}})
    Catalog.put(table, catalog, %{guid: "Branch", parent: %{guid: "Trunk"}})
    Catalog.put(table, catalog, %{guid: "Leaf", parent: %{guid: "Branch"}})

    guids = :ets.tab2list(table) |> Enum.map(fn {guid, _} -> guid end) |> Enum.sort()
    assert guids == ["Branch", "Leaf", "Root", "Trunk"]

    :ok = Catalog.rm_r(table, "Trunk")

    guids = :ets.tab2list(table) |> Enum.map(fn {guid, _} -> guid end) |> Enum.sort()
    assert guids == ["Root"]
  end
end
```

**Step 7: Add ETS-specific tests**

```elixir
describe "ETS direct reads" do
  test "get bypasses GenServer for existing items", %{catalog: catalog, table: table} do
    Catalog.put(table, catalog, %{guid: "Direct"})

    # Suspend the GenServer — if get went through it, this would hang
    :sys.suspend(catalog)
    assert %{guid: "Direct"} = Catalog.get(table, "Direct")
    :sys.resume(catalog)
  end

  test "list bypasses GenServer", %{catalog: catalog, table: table} do
    Catalog.put(table, catalog, %{guid: "X", parent: %{guid: "Root"}, type: "Page"})

    :sys.suspend(catalog)
    assert [%{guid: "X"}] = Catalog.list(table, %{parent: "Root", type: "Page"})
    :sys.resume(catalog)
  end
end
```

**Step 8: Run tests**

Run: `mix test test/sdk/channel/catalog_test.exs`
Expected: All tests pass

**Step 9: Commit**

```bash
git add test/sdk/channel/catalog_test.exs
git commit -m "Update Catalog tests for ETS-backed storage

Tests use table ref for reads and PID for writes/watch. Added tests
verifying reads bypass the GenServer entirely."
```

---

### Task 8: Update Session tests and run full suite

**Files:**
- Modify: `test/sdk/channel/session_test.exs`

**Step 1: Update session test that checks Catalog PID**

The session tests verify `Session.catalog(session)` returns the right PID. Add a test for `catalog_table`:

```elixir
test "catalog_table returns the ETS table ref", %{page: page} do
  table = Session.catalog_table(page.session)
  assert is_reference(table)
  assert :ets.info(table, :type) == :set
end
```

**Step 2: Run formatting check**

Run: `mix format --check-formatted`

**Step 3: Run full test suite**

Run: `mix test`
Expected: 452+ tests, 0 failures

**Step 4: Commit**

```bash
git add test/sdk/channel/session_test.exs
git commit -m "Add Session.catalog_table test, verify full suite passes

All 452+ tests pass with ETS-backed Catalog reads."
```

---

### Task 9: Update Obsidian architecture review note

**Files:**
- Modify: `/Users/trgoodwin/v7-vault/v7/Development/Playwright Elixir Architecture Review.md`

**Step 1: Mark issue as Fixed in summary table**

Change `| Catalog → ETS | High | Medium | Concurrent reads | Open |` to `| Catalog → ETS | High | Medium | Concurrent reads | **Fixed** |`.

**Step 2: Add fix description to "Fixes Applied" section**

Add entry describing the ETS migration.

**Step 3: Update test count**
