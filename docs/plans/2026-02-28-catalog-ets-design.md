# Design: Catalog ETS Migration

> Date: 2026-02-28
> Issue: Architecture Review #1 — Catalog GenServer Bottleneck

## Problem

The Catalog stores every Playwright object in a GenServer-backed map. Every read — including every `@property` accessor on every ChannelOwner (67 properties across 19 modules) — does a `GenServer.call` round-trip, serializing through one process. The real read-to-write ratio is 20:1 to 50:1.

## Approach

**ETS-first reads with GenServer fallback for awaiting/watchers.**

- ETS table (`:set`, `:public`, `read_concurrency: true`) holds all object storage
- Hot-path reads (`get` of existing item, `list`, `rm`) go directly to ETS — no GenServer call
- `get` of a missing item falls back to GenServer, which manages the `awaiting` map (blocking callers until the item arrives)
- `watch` stays as a GenServer call (blocking by design)
- `put` writes to ETS directly, then casts to GenServer to notify awaiting/watcher callers
- Catalog GenServer owns the ETS table (table dies with the process)

## Storage Layer

Catalog GenServer creates the ETS table in `init/1`:

```elixir
:ets.new(:catalog, [:set, :public, {:read_concurrency, true}])
```

Each row is `{guid, resource_struct}`.

The table reference is stored in Session's existing `:persistent_term` map under a `:catalog_table` key.

## Read Path (get of existing item)

```
Catalog.get(table, guid)
  → :ets.lookup(table, guid)
  → if found: return resource (no GenServer call)
  → if not found: GenServer.call(catalog_pid, {:await, guid}, timeout)
       → GenServer checks ETS again (race guard)
       → if still not found: register caller in awaiting map, block
```

## Write Path (put)

```
Catalog.put(catalog_pid, resource)
  → :ets.insert(table, {guid, resource})
  → GenServer.cast(catalog_pid, {:notify, guid, resource})
       → check awaiting map, reply to blocked caller if any
       → check watchers list, reply to matched watchers
```

ETS write is immediate. GenServer cast handles notification asynchronously — writer doesn't block.

## Query Path (list)

```
Catalog.list(table, filter)
  → :ets.tab2list(table)
  → filter in caller's process
```

Direct ETS read, no GenServer.

## Delete Path (rm, rm_r)

```
Catalog.rm(table, guid) → :ets.delete(table, guid)
```

`rm_r` recursive pattern unchanged — calls `list` to find children, recurses, deletes.

## Watch Path

Unchanged — `Catalog.watch` stays as a GenServer call. Blocking by design. GenServer checks ETS for current state; if predicate not met, registers watcher. `put` notifications re-check watchers.

## API Changes

| Function | Takes | Reason |
|----------|-------|--------|
| `get(table, guid)` | ETS table ref | Bypasses GenServer |
| `list(table, filter)` | ETS table ref | Bypasses GenServer |
| `rm(table, guid)` | ETS table ref | Direct ETS delete |
| `rm_r(table, guid, session)` | ETS table ref | Direct ETS operations |
| `put(catalog_pid, resource)` | GenServer PID | Needs to notify awaiting/watchers |
| `watch(catalog_pid, ...)` | GenServer PID | Blocking, needs GenServer |
| `all(table)` | ETS table ref | Direct ETS read |

Callers (`Channel.find`, `Channel.list`, etc.) get the table ref from `:persistent_term`.

## Error Handling

- **ETS table gone** (Catalog died): `:ets.lookup` raises `ArgumentError`. Correct — session is dead, callers should crash.
- **Race in `get` fallback**: Between ETS miss and GenServer call, another process could `put` the item. GenServer's `handle_call(:await, ...)` checks ETS again before registering in `awaiting`.
- **Race in `put` notification**: `put` does `ets.insert` then `GenServer.cast`. Concurrent `get` may see item in ETS before GenServer processes notification — that's fine.

## Lifecycle

- ETS table created in `Catalog.init/1`, owned by Catalog GenServer
- Table dies when Catalog dies (OTP default)
- `terminate/2` replies to awaiting/watcher callers with `{:error, :terminated}`

## Testing

- Existing 452-test suite exercises Catalog transitively
- Add unit tests for:
  - Direct ETS reads bypass GenServer
  - Awaiting fallback (item arrives after `get`)
  - Watcher notification
  - `list` with filters from ETS
  - Cleanup on termination
