defmodule Playwright.SDK.Channel.Session do
  @moduledoc false
  use GenServer
  import Playwright.SDK.Extra.Atom
  alias Playwright.SDK.Channel

  defstruct [:async_bindings, :bindings, :catalog, :connection, :task_supervisor]

  # module init
  # ---------------------------------------------------------------------------

  def child_spec(transport) do
    %{
      id: {__MODULE__, Channel.SessionID.next()},
      start: {__MODULE__, :start_link, [transport]},
      restart: :transient
    }
  end

  def start_link(transport) do
    GenServer.start_link(__MODULE__, transport)
  end

  # @impl init
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(transport) do
    pid = self()
    root = %{session: pid}
    {:ok, catalog} = Channel.Catalog.start_link(root)
    {:ok, connection} = Channel.Connection.start_link({pid, transport})
    {:ok, task_supervisor} = Task.Supervisor.start_link()

    {:ok,
     %__MODULE__{
       async_bindings: %{},
       bindings: %{},
       catalog: catalog,
       connection: connection,
       task_supervisor: task_supervisor
     }}
  end

  # module API
  # ---------------------------------------------------------------------------

  def bind(session, {guid, event_type}, callback) do
    GenServer.cast(session, {:bind, {guid, event_type}, callback})
  end

  def bind_async(session, {guid, event_type}, callback) do
    GenServer.cast(session, {:bind_async, {guid, event_type}, callback})
  end

  def async_bindings(session) do
    GenServer.call(session, :async_bindings)
  end

  def bindings(session) do
    GenServer.call(session, :bindings)
  end

  def catalog(session) do
    GenServer.call(session, :catalog)
  end

  def connection(session) do
    GenServer.call(session, :connection)
  end

  def task_supervisor(session) do
    GenServer.call(session, :task_supervisor)
  end

  # @impl callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def handle_call(:async_bindings, _, %{async_bindings: async_bindings} = state) do
    {:reply, async_bindings, state}
  end

  @impl GenServer
  def handle_call(:bindings, _, %{bindings: bindings} = state) do
    {:reply, bindings, state}
  end

  @impl GenServer
  def handle_call(:catalog, _, %{catalog: catalog} = state) do
    {:reply, catalog, state}
  end

  @impl GenServer
  def handle_call(:connection, _, %{connection: connection} = state) do
    {:reply, connection, state}
  end

  @impl GenServer
  def handle_call(:task_supervisor, _, %{task_supervisor: task_supervisor} = state) do
    {:reply, task_supervisor, state}
  end

  @impl GenServer
  def handle_cast({:bind, {guid, event_type}, callback}, %{bindings: bindings} = state) do
    key = {guid, as_atom(event_type)}
    updated = (bindings[key] || []) ++ [callback]
    bindings = Map.put(bindings, key, updated)
    {:noreply, %{state | bindings: bindings}}
  end

  @impl GenServer
  def handle_cast({:bind_async, {guid, event_type}, callback}, %{async_bindings: async_bindings} = state) do
    key = {guid, as_atom(event_type)}
    updated = (async_bindings[key] || []) ++ [callback]
    async_bindings = Map.put(async_bindings, key, updated)
    {:noreply, %{state | async_bindings: async_bindings}}
  end

  # private
  # ---------------------------------------------------------------------------

  defp as_atom(value) when is_atom(value) do
    value
  end

  defp as_atom(value) when is_binary(value) do
    snakecased(value)
  end
end
