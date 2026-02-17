defmodule Playwright.BrowserType.LaunchTest do
  use Playwright.TestCase, async: true

  describe "BrowserType.launch/2" do
    test "launches Chromium", %{assets: assets} do
      {_session, browser} = Playwright.BrowserType.launch(:chromium)
      on_exit(fn -> Playwright.Browser.close(browser) end)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
    end

    test "launches Firefox", %{assets: assets} do
      {_session, browser} = Playwright.BrowserType.launch(:firefox)
      on_exit(fn -> Playwright.Browser.close(browser) end)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
    end

    test "launches WebKit", %{assets: assets} do
      {_session, browser} = Playwright.BrowserType.launch(:webkit)
      on_exit(fn -> Playwright.Browser.close(browser) end)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
    end
  end
end
