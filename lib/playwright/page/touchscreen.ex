defmodule Playwright.Page.Touchscreen do
  @moduledoc false

  use Playwright.SDK.ChannelOwner
  alias Playwright.Page

  # API
  # ---------------------------------------------------------------------------

  @spec tap(Page.t(), number(), number()) :: Page.t()
  def tap(page, x, y) do
    post!(page, :touchscreen_tap, %{x: x, y: y})
  end
end
