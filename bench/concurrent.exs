# Concurrent read throughput benchmark: ETS (current) vs GenServer (old)
#
# Shows GenServer mailbox serialization vs ETS linear scaling.
#
# Run: mix run bench/concurrent.exs

defmodule Bench.OldCatalog do
  @moduledoc false
  use GenServer

  def start_link(items \\ %{}) do
    GenServer.start_link(__MODULE__, items)
  end

  def get(pid, guid), do: GenServer.call(pid, {:get, guid})

  @impl GenServer
  def init(items), do: {:ok, items}

  @impl GenServer
  def handle_call({:get, guid}, _from, items) do
    {:reply, Map.get(items, guid), items}
  end
end

n = 500
reads_per_reader = 100

items =
  for i <- 1..n, into: %{} do
    guid = "item-#{i}"
    {guid, %{guid: guid, type: "Page", value: i}}
  end

# Setup old catalog (GenServer)
{:ok, old_pid} = Bench.OldCatalog.start_link(items)

# Setup new catalog (ETS)
table = :ets.new(:bench_concurrent, [:set, :public, {:read_concurrency, true}])
Enum.each(items, fn {guid, item} -> :ets.insert(table, {guid, item}) end)

# Pre-generate random GUIDs for deterministic workload
guids = for _ <- 1..reads_per_reader, do: "item-#{Enum.random(1..n)}"

do_reads_genserver = fn ->
  Enum.each(guids, &Bench.OldCatalog.get(old_pid, &1))
end

do_reads_ets = fn ->
  Enum.each(guids, fn guid ->
    :ets.lookup(table, guid)
  end)
end

for concurrency <- [1, 4, 8, 16] do
  work = List.duplicate(:work, concurrency)

  Benchee.run(
    %{
      "GenServer (old)" => fn ->
        work
        |> Task.async_stream(fn _ -> do_reads_genserver.() end, max_concurrency: concurrency)
        |> Stream.run()
      end,
      "ETS (new)" => fn ->
        work
        |> Task.async_stream(fn _ -> do_reads_ets.() end, max_concurrency: concurrency)
        |> Stream.run()
      end
    },
    title: "Concurrent Reads — #{concurrency} readers x #{reads_per_reader} gets",
    warmup: 1,
    time: 3,
    print: [benchmarking: false]
  )
end
