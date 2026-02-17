defmodule Playwright.Page.MouseTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, Page.Mouse}

  describe "Mouse.click/4" do
    test "clicks at coordinates", %{page: page} do
      Page.set_content(page, """
      <button onclick="window._clicked = true" style="width:100px;height:100px;">Click me</button>
      """)

      Mouse.click(page, 50, 50)

      result = Page.evaluate(page, "() => window._clicked")
      assert result == true
    end
  end

  describe "Mouse.dblclick/4" do
    test "double-clicks at coordinates", %{page: page} do
      Page.set_content(page, """
      <button ondblclick="window._dblclicked = true" style="width:100px;height:100px;">Double click</button>
      """)

      Mouse.dblclick(page, 50, 50)

      result = Page.evaluate(page, "() => window._dblclicked")
      assert result == true
    end
  end

  describe "Mouse.move/4" do
    test "moves the mouse to coordinates", %{page: page} do
      Page.set_content(page, """
      <div onmouseover="window._hovered = true" style="width:100px;height:100px;">Hover</div>
      """)

      Mouse.move(page, 50, 50)

      result = Page.evaluate(page, "() => window._hovered")
      assert result == true
    end
  end

  describe "Mouse.down/2 and Mouse.up/2" do
    test "press and release mouse button", %{page: page} do
      Page.set_content(page, """
      <div style="width:100px;height:100px;"
           onmousedown="window._mousedown = true"
           onmouseup="window._mouseup = true">Press</div>
      """)

      Mouse.move(page, 50, 50)
      Mouse.down(page)

      assert Page.evaluate(page, "() => window._mousedown") == true

      Mouse.up(page)

      assert Page.evaluate(page, "() => window._mouseup") == true
    end
  end

  describe "Mouse.wheel/3" do
    test "scrolls the mouse wheel", %{page: page} do
      Page.set_content(page, """
      <div style="height:2000px;">
        <div id="top">Top</div>
      </div>
      """)

      Mouse.wheel(page, 0, 500)

      # Give the page a moment to process the scroll
      Process.sleep(100)

      scroll_y = Page.evaluate(page, "() => window.scrollY")
      assert scroll_y > 0
    end
  end
end
