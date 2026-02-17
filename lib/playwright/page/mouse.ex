defmodule Playwright.Page.Mouse do
  @moduledoc false

  use Playwright.SDK.ChannelOwner
  alias Playwright.Page

  @type options :: map()

  # API
  # ---------------------------------------------------------------------------

  @spec click(Page.t(), number(), number(), options()) :: Page.t()
  def click(page, x, y, options \\ %{}) do
    params = Map.merge(%{x: x, y: y, delay: 0, button: "left", click_count: 1}, options)
    post!(page, :mouse_click, params)
  end

  @spec dblclick(Page.t(), number(), number(), options()) :: Page.t()
  def dblclick(page, x, y, options \\ %{}) do
    params = Map.merge(%{x: x, y: y, delay: 0, button: "left", click_count: 2}, options)
    post!(page, :mouse_click, params)
  end

  @spec down(Page.t(), options()) :: Page.t()
  def down(page, options \\ %{}) do
    params = Map.merge(%{button: "left", click_count: 1}, options)
    post!(page, :mouse_down, params)
  end

  @spec move(Page.t(), number(), number(), options()) :: Page.t()
  def move(page, x, y, options \\ %{}) do
    params = Map.merge(%{x: x, y: y, steps: 1}, options)
    post!(page, :mouse_move, params)
  end

  @spec up(Page.t(), options()) :: Page.t()
  def up(page, options \\ %{}) do
    params = Map.merge(%{button: "left", click_count: 1}, options)
    post!(page, :mouse_up, params)
  end

  @spec wheel(Page.t(), number(), number()) :: Page.t()
  def wheel(page, delta_x, delta_y) do
    post!(page, :mouse_wheel, %{delta_x: delta_x, delta_y: delta_y})
  end
end
