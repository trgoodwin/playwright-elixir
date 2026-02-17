defmodule Playwright.Page.TouchscreenTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, BrowserContext, Page, Page.Touchscreen}

  describe "Touchscreen.tap/3" do
    @tag exclude: [:page]
    test "taps at coordinates", %{browser: browser} do
      context = Browser.new_context(browser, %{has_touch: true})
      page = BrowserContext.new_page(context)

      Page.set_content(page, """
      <div id="target" style="width:100px;height:100px;"
           ontouchstart="window._tapped = true">Tap me</div>
      """)

      Touchscreen.tap(page, 50, 50)

      result = Page.evaluate(page, "() => window._tapped")
      assert result == true

      Page.close(page)
      BrowserContext.close(context)
    end
  end
end
