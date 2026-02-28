defmodule Playwright.SDK.Channel.Catalog do
  @moduledoc """
  Provides storage and management of ChannelOwner instances.

  `Catalog` implements `GenServer` to maintain state, while domain logic is
  expected to be handled within caller modules such as `Playwright.SDK.Channel`.
  """
  use GenServer
  import Playwright.SDK.Helpers.ErrorHandling
  alias Playwright.SDK.Channel

  defstruct [:awaiting, :table, watchers: []]

  # module init
  # ---------------------------------------------------------------------------

  @doc """
  Starts a `Playwright.SDK.Channel.Catalog` linked to the current process with the
  given "root" resource.

  ## Return Values

  If the `Catalog` is successfully created and initialized, the function
  returns `{:ok, pid}`, where `pid` is the PID of the running `Catalog` server.

  ## Arguments

  | key/name | type   |         | description |
  | -------- | ------ | ------- | ----------- |
  | `root`   | param  | `map()` | The root resource for items in the `Catalog`. Provides the `Session` for its descendants |
  """
  @spec start_link(map()) :: {:ok, pid()}
  def start_link(root) do
    GenServer.start_link(__MODULE__, root)
  end

  # @impl init
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(root) do
    Process.flag(:trap_exit, true)
    table = :ets.new(:catalog, [:set, :public, {:read_concurrency, true}])
    :ets.insert(table, {"Root", root})
    {:ok, %__MODULE__{awaiting: %{}, table: table, watchers: []}}
  end

  # module API
  # ---------------------------------------------------------------------------

  def table(catalog) do
    GenServer.call(catalog, :table)
  end

  def all(table) when is_reference(table) do
    :ets.tab2list(table) |> Map.new()
  end

  @doc """
  Retrieves a resource from the `Catalog` by its `param: guid`.

  If the resource is already present in the `Catalog` that resource is returned
  directly. The desired resource might not yet be in the `Catalog`, in which
  case the request will be considered as "awaiting". An awaiting request will
  later receive a response, when the `Catalog` entry is made, or will time out.

  ## Returns

  - `resource`
  - `{:error, error}`

  ## Arguments

  | key/name   | type   |            | description |
  | ---------- | ------ | ---------- | ----------- |
  | `table`    | param  | `reference()` | ETS table reference |
  | `guid`     | param  | `binary()` | GUID to look up |
  | `:timeout` | option | `float()`  | Maximum time to wait, in milliseconds. Defaults to `30_000` (30 seconds). |
  """
  @spec get(:ets.table(), binary(), map()) :: struct() | {:error, Channel.Error.t()}
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

  @doc """
  Waits for a resource in the `Catalog` to satisfy a predicate.

  If the resource already satisfies the predicate, returns immediately.
  Otherwise, the caller blocks until the resource is updated (via `put/2`)
  and the predicate returns truthy, or until the timeout is exceeded.

  ## Returns

  - `resource`
  - `{:error, error}`

  ## Arguments

  | key/name    | type   |              | description |
  | ----------- | ------ | ------------ | ----------- |
  | `catalog`   | param  | `pid()`      | PID for the Catalog server |
  | `guid`      | param  | `binary()`   | GUID to watch |
  | `predicate` | param  | `function()` | A 1-arity function that receives the resource and returns truthy when satisfied |
  | `:timeout`  | option | `float()`    | Maximum time to wait, in milliseconds. Defaults to `30_000` (30 seconds). |
  """
  @spec watch(pid(), binary(), (struct() -> boolean()), map()) :: struct() | {:error, Channel.Error.t()}
  def watch(catalog, guid, predicate, options \\ %{}) do
    with_timeout(options, fn timeout ->
      GenServer.call(catalog, {:watch, guid, predicate}, timeout)
    end)
  end

  @doc """
  Returns a `List` of resources matching the provided "filter".

  ## Returns

  - [`resource`]
  - []

  ## Arguments

  | key/name  | type   |              | description |
  | --------- | ------ | ------------ | ----------- |
  | `table`   | param  | `reference()` | ETS table reference |
  | `filter`  | param  | `map()`      | Attributes for filtering |
  """
  @spec list(:ets.table(), map()) :: [struct()]
  def list(table, filter) when is_reference(table) do
    items = :ets.tab2list(table) |> Enum.map(fn {_guid, item} -> item end)
    filter(items, normalize_parent(filter), [])
  end

  @doc """
  Adds a resource to the `Catalog`, keyed on `:guid`.

  ## Returns

  - `resource` (the same as provided)

  ## Arguments

  | key/name   | type   |              | description |
  | ---------- | ------ | ------------ | ----------- |
  | `table`    | param  | `reference()` | ETS table reference |
  | `catalog`  | param  | `pid()`      | PID for the Catalog server |
  | `resource` | param  | `struct()`   | The resource to store |
  """
  @spec put(:ets.table(), pid(), struct()) :: struct()
  def put(table, catalog, %{guid: guid} = resource) when is_reference(table) do
    :ets.insert(table, {guid, resource})
    GenServer.cast(catalog, {:notify, guid, resource})
    resource
  end

  @doc """
  Removes a resource from the `Catalog`, along with its legacy.

  ## Returns

  - `:ok`

  ## Arguments

  | key/name   | type   |              | description |
  | ---------- | ------ | ------------ | ----------- |
  | `table`    | param  | `reference()` | ETS table reference |
  | `guid`     | param  | `binary()`   | GUID for the "parent" |
  """
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

  # @impl callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def handle_call(:table, _, %{table: table} = state) do
    {:reply, table, state}
  end

  @impl GenServer
  def handle_call({:await, guid}, from, %{awaiting: awaiting, table: table} = state) do
    case :ets.lookup(table, guid) do
      [{^guid, item}] -> {:reply, item, state}
      [] -> {:noreply, %{state | awaiting: Map.put(awaiting, guid, from)}}
    end
  end

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

  @impl GenServer
  def handle_cast({:notify, guid, item}, %{awaiting: awaiting, watchers: watchers} = state) do
    {caller, awaiting} = Map.pop(awaiting, guid)
    if caller, do: GenServer.reply(caller, item)

    {matched, remaining} =
      Enum.split_with(watchers, fn {watcher_guid, predicate, _from} ->
        watcher_guid == guid && predicate.(item)
      end)

    Enum.each(matched, fn {_guid, _predicate, from} ->
      GenServer.reply(from, item)
    end)

    {:noreply, %{state | awaiting: awaiting, watchers: remaining}}
  end

  @impl GenServer
  def terminate(_reason, %{awaiting: awaiting, watchers: watchers}) do
    Enum.each(awaiting, fn {_guid, from} ->
      GenServer.reply(from, {:error, :terminated})
    end)

    Enum.each(watchers, fn {_guid, _predicate, from} ->
      GenServer.reply(from, {:error, :terminated})
    end)

    :ok
  end

  # private
  # ---------------------------------------------------------------------------

  defp filter([], _attrs, result) do
    result
  end

  defp filter([head | tail], attrs, result) when head.type == "" do
    filter(tail, attrs, result)
  end

  defp filter([head | tail], %{parent: parent, type: type} = attrs, result)
       when head.parent.guid == parent and head.type == type do
    filter(tail, attrs, result ++ [head])
  end

  defp filter([head | tail], %{parent: parent, type: type} = attrs, result)
       when head.parent.guid != parent or head.type != type do
    filter(tail, attrs, result)
  end

  defp filter([head | tail], %{parent: parent} = attrs, result)
       when head.parent.guid == parent do
    filter(tail, attrs, result ++ [head])
  end

  defp filter([head | tail], %{type: type} = attrs, result)
       when head.type == type do
    filter(tail, attrs, result ++ [head])
  end

  defp filter([head | tail], %{guid: guid} = attrs, result)
       when head.guid == guid do
    filter(tail, attrs, result ++ [head])
  end

  defp filter([_head | tail], attrs, result) do
    filter(tail, attrs, result)
  end

  defp normalize_parent(%{parent: %{guid: guid}} = filter), do: %{filter | parent: guid}
  defp normalize_parent(%{parent: parent} = filter) when is_binary(parent), do: filter
  defp normalize_parent(filter), do: filter

  defp rm(table, guid) when is_reference(table) do
    :ets.delete(table, guid)
    :ok
  end
end
