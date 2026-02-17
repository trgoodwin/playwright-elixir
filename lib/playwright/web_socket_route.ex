defmodule Playwright.WebSocketRoute do
  @moduledoc false

  @enforce_keys [:url]
  defstruct [:url, :server, :context]

  @type t :: %__MODULE__{}

  # @spec close(t(), map()) :: :ok
  # def close(route, options \\ %{})

  # @spec connect_to_server(t()) :: t()
  # def connect_to_server(route)

  # @spec on_close(t(), function()) :: :ok
  # def on_close(route, handler)

  # @spec on_message(t(), function()) :: :ok
  # def on_message(route, handler)

  # @spec send(t(), binary()) :: :ok
  # def send(route, message)

  @spec url(t()) :: binary()
  def url(%__MODULE__{url: url}), do: url
end
