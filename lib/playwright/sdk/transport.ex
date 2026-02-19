defmodule Playwright.SDK.Transport do
  @moduledoc false
  use GenServer
  require Logger
  import Playwright.SDK.Extra.Map
  alias Playwright.SDK.Channel.Connection

  defstruct [:connection, :transport]

  # module init
  # ---------------------------------------------------------------------------

  def start_link(kind) do
    GenServer.start_link(__MODULE__, kind, timeout: 1000)
  end

  def start_link!(kind) do
    {:ok, pid} = start_link(kind)
    pid
  end

  # @impl init
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init({connection, {module, config}}) do
    state = %__MODULE__{
      connection: connection,
      transport: {module, module.setup(config)}
    }

    {:ok, state}
  end

  # module API
  # ---------------------------------------------------------------------------

  # def post(transport, %Message{} = message) do
  def post(transport, %{} = message) do
    GenServer.cast(transport, {:post, message})
  end

  # @impl callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def handle_cast({:post, message}, %{transport: {module, data}} = state) do
    module.post(serialize(message), data)
    {:noreply, state}
  end

  # WebSocket: gun process monitored via Process.monitor in setup
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.error("[transport] Connection lost: #{inspect(reason)}")
    {:stop, {:transport_closed, reason}, state}
  end

  # Driver: port monitored via Port.monitor in setup
  @impl GenServer
  def handle_info({:DOWN, _ref, :port, _port, reason}, state) do
    Logger.error("[transport] Driver process exited: #{inspect(reason)}")
    {:stop, {:transport_closed, reason}, state}
  end

  @impl GenServer
  def handle_info(info, %{connection: connection, transport: {module, data}} = state) do
    {messages, updates} = module.parse(info, data)

    messages
    |> Enum.each(fn message ->
      Connection.recv(connection, deserialize(message))
    end)

    {:noreply, %{state | transport: {module, Map.merge(data, updates)}}}
  end

  # private
  # ----------------------------------------------------------------------------

  defp deserialize(json) do
    case Jason.decode(json) do
      {:ok, data} ->
        deep_atomize_keys(data)

      error ->
        raise ArgumentError,
          message: "error: #{inspect(error)}; #{inspect(json: Enum.join(for <<c::utf8 <- json>>, do: <<c::utf8>>))}"
    end
  end

  defp serialize(message) do
    Jason.encode!(message)
  end
end
