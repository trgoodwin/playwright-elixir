defmodule Playwright.WebSocket do
  @moduledoc """
  `WebSocket` represents a WebSocket connection created by a page.

  Events emitted by the WebSocket can be subscribed to via `on/3`:

  - `:close` — the WebSocket was closed.
  - `:framereceived` — a frame was received (params include `data` and `opcode`).
  - `:framesent` — a frame was sent (params include `data` and `opcode`).
  - `:socketerror` — an error occurred (params include `error`).
  """
  use Playwright.SDK.ChannelOwner
  alias Playwright.SDK.ChannelOwner

  @property :is_closed
  @property :url

  # callbacks
  # ---------------------------------------------------------------------------

  @impl ChannelOwner
  def init(%__MODULE__{session: session} = ws, _initializer) do
    Channel.bind(session, {:guid, ws.guid}, :close, fn event ->
      {:patch, %{event.target | is_closed: true}}
    end)

    {:ok, ws}
  end

  # API
  # ---------------------------------------------------------------------------

  @doc """
  Register a (non-blocking) callback/handler for various types of events.

  ## Supported events

  - `:close` — the WebSocket was closed.
  - `:framereceived` — a frame was received.
  - `:framesent` — a frame was sent.
  - `:socketerror` — an error occurred.

  ## Arguments

  | key/name   | type       |             | description |
  | ---------- | ---------- | ----------- | ----------- |
  | `web_socket` | param | `t()` | The WebSocket. |
  | `event`      | param | `atom()` | The event type. |
  | `callback`   | param | `function()` | The callback function. |

  ## Returns

  - `:ok`
  """
  @spec on(t(), atom(), function()) :: :ok
  def on(%__MODULE__{session: session, guid: guid}, event, callback) when is_atom(event) do
    Channel.bind_async(session, {:guid, guid}, event, callback)
    :ok
  end

  # @spec expect_event(t(), binary(), function(), options()) :: map()
  # def expect_event(web_socket, event, predicate \\ nil, options \\ %{})
  # ...delegate wait_for_event -> expect_event
end
