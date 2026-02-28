# Catalog CRUD benchmark: ETS (current) vs GenServer-backed map (old)
#
# Run: mix run bench/catalog.exs

defmodule Bench.OldCatalog do
  @moduledoc false
  use GenServer

  def start_link(items \\ %{}) do
    GenServer.start_link(__MODULE__, items)
  end

  def get(pid, guid), do: GenServer.call(pid, {:get, guid})
  def put(pid, guid, item), do: GenServer.call(pid, {:put, guid, item})
  def list(pid), do: GenServer.call(pid, :list)

  @impl GenServer
  def init(items), do: {:ok, items}

  @impl GenServer
  def handle_call({:get, guid}, _from, items) do
    {:reply, Map.get(items, guid), items}
  end

  def handle_call({:put, guid, item}, _from, items) do
    {:reply, :ok, Map.put(items, guid, item)}
  end

  def handle_call(:list, _from, items) do
    {:reply, items, items}
  end
end

alias Playwright.SDK.Channel.Catalog

n = 500

# Build items
items =
  for i <- 1..n, into: %{} do
    guid = "item-#{i}"
    {guid, %{guid: guid, type: "Page", value: i}}
  end

# Setup old catalog (GenServer)
{:ok, old_pid} = Bench.OldCatalog.start_link(items)

# Setup new catalog (ETS)
table = :ets.new(:bench_catalog, [:set, :public, {:read_concurrency, true}])
Enum.each(items, fn {guid, item} -> :ets.insert(table, {guid, item}) end)

# A catalog GenServer is needed for put notifications — start a real one
root = %{session: self()}
{:ok, catalog_pid} = Catalog.start_link(root)
catalog_table = Catalog.table(catalog_pid)
Enum.each(items, fn {_guid, item} -> Catalog.put(catalog_table, catalog_pid, item) end)

# Pick a known GUID for single-get benchmarks
hit_guid = "item-250"
write_item = %{guid: "item-write", type: "Page", value: :write}

Benchee.run(
  %{
    "GenServer get (old)" => fn -> Bench.OldCatalog.get(old_pid, hit_guid) end,
    "ETS get (new)" => fn -> Catalog.get(catalog_table, hit_guid) end
  },
  title: "Catalog — Single Get",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

Benchee.run(
  %{
    "GenServer list (old)" => fn -> Bench.OldCatalog.list(old_pid) end,
    "ETS all (new)" => fn -> Catalog.all(catalog_table) end
  },
  title: "Catalog — List All (#{n} items)",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

Benchee.run(
  %{
    "GenServer put (old)" => fn -> Bench.OldCatalog.put(old_pid, "item-write", write_item) end,
    "ETS put (new)" => fn -> Catalog.put(catalog_table, catalog_pid, write_item) end
  },
  title: "Catalog — Single Put",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

# Mixed read/write: 20 gets + 1 put
guids = for _i <- 1..20, do: "item-#{Enum.random(1..n)}"

Benchee.run(
  %{
    "GenServer mixed 20:1 (old)" => fn ->
      Enum.each(guids, &Bench.OldCatalog.get(old_pid, &1))
      Bench.OldCatalog.put(old_pid, "item-write", write_item)
    end,
    "ETS mixed 20:1 (new)" => fn ->
      Enum.each(guids, &Catalog.get(catalog_table, &1))
      Catalog.put(catalog_table, catalog_pid, write_item)
    end
  },
  title: "Catalog — Mixed Read/Write (20:1)",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)
