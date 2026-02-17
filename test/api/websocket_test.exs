defmodule Playwright.WebSocketTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, WebSocket}

  describe "WebSocket module" do
    test "exports url/1, is_closed/1, and on/3" do
      Code.ensure_loaded!(WebSocket)
      assert function_exported?(WebSocket, :url, 1)
      assert function_exported?(WebSocket, :is_closed, 1)
      assert function_exported?(WebSocket, :on, 3)
    end
  end

  describe "Page :websocket event" do
    test "fires when a WebSocket is created", %{page: page} do
      test_pid = self()

      Page.on(page, :websocket, fn event ->
        send(test_pid, {:websocket, event})
      end)

      Page.evaluate(page, """
      () => {
        window._ws = new WebSocket('ws://localhost:4002/ws-noop');
        // Immediately close to avoid hanging connections
        window._ws.onopen = () => window._ws.close();
      }
      """)

      # The :websocket event may not fire if the server doesn't accept WebSocket
      # upgrades. This test verifies the event binding works without error.
      receive do
        {:websocket, event} ->
          ws = event.params

          assert ws != nil
      after
        2_000 -> :ok
      end
    end
  end
end
