defmodule Playwright.ConsoleMessage do
  @moduledoc """
  `Playwright.ConsoleMessage` instances are dispatched by page and handled via
  `Playwright.Page.on/3` for the `:console` event type.

  Console events deliver message data inline in the event params. Use
  `from_event/1` to wrap the event into a map that can be passed to
  `text/1`, `type/1`, and `location/1`.

  ## Example

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        IO.puts(ConsoleMessage.text(msg))
      end)
  """
  use Playwright.SDK.ChannelOwner
  alias Playwright.SDK.ChannelOwner

  @property :message_text
  @property :message_type

  # callbacks
  # ---------------------------------------------------------------------------

  @impl ChannelOwner
  def init(message, initializer) do
    {:ok, %{message | message_text: initializer.text, message_type: initializer.type}}
  end

  # API
  # ---------------------------------------------------------------------------

  @doc """
  Wraps the console event into a map with `:text`, `:type`, `:location`,
  `:args`, and `:page` keys.

  The callback registered via `Page.on(page, :console, callback)` receives a
  `%Playwright.SDK.Channel.Event{}` struct. Pass it directly to this function.
  """
  @spec from_event(map()) :: map()
  def from_event(%{params: params}) do
    %{
      text: Map.get(params, :text),
      type: Map.get(params, :type),
      location: Map.get(params, :location, %{}),
      args: Map.get(params, :args, []),
      page: Map.get(params, :page)
    }
  end

  @doc """
  Returns the text of the console message.

  Accepts a `%ConsoleMessage{}` struct or a map with a `:text` key
  (e.g., the result of `from_event/1`).
  """
  @spec text(t() | map()) :: String.t()
  def text(%__MODULE__{} = message), do: message_text(message)
  def text(%{text: text}), do: text

  @doc """
  Returns the type of the console message.

  Can be one of `"log"`, `"error"`, `"warning"`, `"info"`, `"debug"`, etc.

  Accepts a `%ConsoleMessage{}` struct or a map with a `:type` key
  (e.g., the result of `from_event/1`).
  """
  @spec type(t() | map()) :: String.t()
  def type(%__MODULE__{} = message), do: message_type(message)
  def type(%{type: type}), do: type

  @doc """
  Returns the location in the source where the console API was called.

  The location is a map with keys such as `:url`, `:lineNumber`, and
  `:columnNumber`.

  Accepts a `%ConsoleMessage{}` struct (reads from the initializer) or a map
  with a `:location` key (e.g., the result of `from_event/1`).
  """
  @spec location(t() | map()) :: map()
  def location(%__MODULE__{initializer: initializer}) do
    Map.get(initializer || %{}, :location, %{})
  end

  def location(%{location: location}), do: location || %{}

  @doc """
  Returns the list of arguments passed to the console call.

  Accepts a `%ConsoleMessage{}` struct (resolves JSHandle GUIDs from the
  initializer's `args` list) or a map with an `:args` key (e.g., the result
  of `from_event/1`).
  """
  @spec args(t() | map()) :: [Playwright.JSHandle.t()]
  def args(%__MODULE__{session: session, initializer: initializer}) do
    (initializer || %{})
    |> Map.get(:args, [])
    |> Enum.map(fn
      %{guid: guid} -> Channel.find(session, {:guid, guid})
      other -> other
    end)
  end

  def args(%{args: args}), do: args || []

  @doc """
  Returns the page that produced this console message.

  Accepts a `%ConsoleMessage{}` struct (walks the parent chain to find
  the `%Page{}`) or a map with a `:page` key (e.g., from `from_event/1`).
  """
  @spec page(t() | map()) :: Playwright.Page.t() | nil
  def page(%__MODULE__{session: session, parent: parent}) do
    do_find_page(session, parent)
  end

  def page(%{page: page}), do: page

  defp do_find_page(_session, nil), do: nil

  defp do_find_page(_session, %Playwright.Page{} = page), do: page

  defp do_find_page(session, %{parent: %{guid: parent_guid}}) do
    parent = Channel.find(session, {:guid, parent_guid})
    do_find_page(session, parent)
  end

  defp do_find_page(_session, _other), do: nil
end
