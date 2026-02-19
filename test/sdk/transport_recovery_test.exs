defmodule Playwright.SDK.TransportRecoveryTest do
  use ExUnit.Case, async: true
  alias Playwright.SDK.Transport
  alias Playwright.SDK.Channel.{Connection, Error}

  # Minimal transport module that satisfies the Transport GenServer interface.
  # Replaces the real Driver/WebSocket with no-ops for isolated testing.
  defmodule FakeTransport do
    def setup(_config), do: %{}
    def post(_message, _state), do: :ok
    def parse(_info, state), do: {[], state}
  end

  describe "Transport handle_info :DOWN" do
    test "process :DOWN stops with {:transport_closed, reason}" do
      state = %Transport{connection: self(), transport: {FakeTransport, %{}}}

      assert {:stop, {:transport_closed, :connection_reset}, ^state} =
               Transport.handle_info({:DOWN, make_ref(), :process, self(), :connection_reset}, state)
    end

    test "port :DOWN stops with {:transport_closed, reason}" do
      state = %Transport{connection: self(), transport: {FakeTransport, %{}}}

      assert {:stop, {:transport_closed, :normal}, ^state} =
               Transport.handle_info({:DOWN, make_ref(), :port, self(), :normal}, state)
    end
  end

  describe "Connection stops when Transport exits" do
    test "terminates with {:transport_closed, reason}" do
      Process.flag(:trap_exit, true)
      session = spawn_link(fn -> Process.sleep(:infinity) end)
      {:ok, connection} = Connection.start_link({session, {FakeTransport, %{}}})
      ref = Process.monitor(connection)

      %{transport: transport} = :sys.get_state(connection)
      assert Process.alive?(transport)

      Process.exit(transport, :kill)

      assert_receive {:DOWN, ^ref, :process, ^connection, {:transport_closed, :killed}}, 1000
    end
  end

  describe "Connection terminate replies to pending callers" do
    setup do
      Process.flag(:trap_exit, true)
      session = spawn_link(fn -> Process.sleep(:infinity) end)
      {:ok, connection} = Connection.start_link({session, {FakeTransport, %{}}})
      %{connection: connection}
    end

    test "pending post callers receive {:error, %Error{}}", %{connection: connection} do
      task =
        Task.async(fn ->
          Connection.post(connection, %{id: 1, guid: "test", method: "test", params: %{}, metadata: %{}}, 5000)
        end)

      Process.sleep(50)
      GenServer.stop(connection, :shutdown)

      assert {:error, %Error{}} = Task.await(task, 1000)
    end

    test "pending wait callers receive {:error, %Error{}}", %{connection: connection} do
      task =
        Task.async(fn ->
          Connection.wait(connection, {:guid, "some-guid"}, :some_event, 5000)
        end)

      Process.sleep(50)
      GenServer.stop(connection, :shutdown)

      assert {:error, %Error{}} = Task.await(task, 1000)
    end

    test "transport death replies to pending callers with {:error, %Error{}}", %{connection: connection} do
      task =
        Task.async(fn ->
          Connection.post(connection, %{id: 2, guid: "test", method: "action", params: %{}, metadata: %{}}, 5000)
        end)

      Process.sleep(50)
      %{transport: transport} = :sys.get_state(connection)
      Process.exit(transport, :kill)

      assert {:error, %Error{}} = Task.await(task, 1000)
    end
  end
end
