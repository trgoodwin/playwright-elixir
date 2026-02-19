defmodule Playwright.SDK.Channel.Session do
  @moduledoc false
  use GenServer
  import Playwright.SDK.Extra.Atom
  alias Playwright.SDK.Channel

  defstruct [:async_bindings, :bindings, :catalog, :connection, :supervisor, :task_supervisor]

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

    children = [
      %{id: :task_supervisor, start: {Task.Supervisor, :start_link, [[]]}, type: :supervisor},
      %{id: Channel.Catalog, start: {Channel.Catalog, :start_link, [root]}},
      %{id: Channel.Connection, start: {Channel.Connection, :start_link, [{pid, transport}]}}
    ]

    {:ok, supervisor} =
      Supervisor.start_link(children, strategy: :one_for_all, max_restarts: 0)

    children_map =
      for {id, child_pid, _, _} <- Supervisor.which_children(supervisor),
          into: %{},
          do: {id, child_pid}

    {:ok,
     %__MODULE__{
       async_bindings: %{},
       bindings: %{},
       catalog: children_map[Channel.Catalog],
       connection: children_map[Channel.Connection],
       supervisor: supervisor,
       task_supervisor: children_map[:task_supervisor]
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

  def unbind_all(session, guid) do
    GenServer.cast(session, {:unbind_all, guid})
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

  @impl GenServer
  def handle_cast({:unbind_all, guid}, %{bindings: bindings, async_bindings: async_bindings} = state) do
    bindings = Map.reject(bindings, fn {{g, _}, _} -> g == guid end)
    async_bindings = Map.reject(async_bindings, fn {{g, _}, _} -> g == guid end)
    {:noreply, %{state | bindings: bindings, async_bindings: async_bindings}}
  end

  @impl GenServer
  def terminate(_reason, %{supervisor: supervisor}) when is_pid(supervisor) do
    Supervisor.stop(supervisor, :shutdown)
  end

  def terminate(_reason, _state), do: :ok

  # private
  # ---------------------------------------------------------------------------

  defp as_atom(value) when is_atom(value) do
    value
  end

  defp as_atom(value) when is_binary(value) do
    snakecased(value)
  end
end
