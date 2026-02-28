# Session PID lookup benchmark: persistent_term (current) vs GenServer.call (old)
#
# Run: mix run bench/session.exs

defmodule Bench.OldSession do
  @moduledoc false
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def catalog(pid), do: GenServer.call(pid, :catalog)
  def catalog_table(pid), do: GenServer.call(pid, :catalog_table)
  def connection(pid), do: GenServer.call(pid, :connection)
  def task_supervisor(pid), do: GenServer.call(pid, :task_supervisor)

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_call(key, _from, state) do
    {:reply, Map.get(state, key), state}
  end
end

# Simulate session children PIDs
state = %{
  catalog: :c.pid(0, 100, 0),
  catalog_table: :c.pid(0, 101, 0),
  connection: :c.pid(0, 102, 0),
  task_supervisor: :c.pid(0, 103, 0)
}

{:ok, old_pid} = Bench.OldSession.start_link(state)

# Setup persistent_term (current approach)
session_key = {Playwright.SDK.Channel.Session, :bench_session}
:persistent_term.put(session_key, state)

IO.puts("")

Benchee.run(
  %{
    "GenServer.call (old)" => fn -> Bench.OldSession.catalog(old_pid) end,
    "persistent_term (new)" => fn -> :persistent_term.get(session_key).catalog end
  },
  title: "Session — Single Lookup",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

Benchee.run(
  %{
    "GenServer.call x3 (old)" => fn ->
      Bench.OldSession.catalog(old_pid)
      Bench.OldSession.connection(old_pid)
      Bench.OldSession.task_supervisor(old_pid)
    end,
    "persistent_term x3 (new)" => fn ->
      data = :persistent_term.get(session_key)
      data.catalog
      data.connection
      data.task_supervisor
    end
  },
  title: "Session — Triple Lookup",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

# Channel.post preamble: needs connection + catalog_table
Benchee.run(
  %{
    "GenServer.call x2 (old)" => fn ->
      Bench.OldSession.connection(old_pid)
      Bench.OldSession.catalog_table(old_pid)
    end,
    "persistent_term x2 (new)" => fn ->
      data = :persistent_term.get(session_key)
      data.connection
      data.catalog_table
    end
  },
  title: "Session — Channel.post Preamble (connection + catalog_table)",
  warmup: 1,
  time: 3,
  print: [benchmarking: false]
)

# Cleanup
:persistent_term.erase(session_key)
