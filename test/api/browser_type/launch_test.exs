defmodule Playwright.BrowserType.LaunchTest do
  use Playwright.TestCase, async: true

  describe "BrowserType.launch/2" do
    test "launches Firefox", %{assets: assets} do
      {_session, browser} = Playwright.BrowserType.launch(:firefox)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
      Playwright.Browser.close(browser)
    end

    test "launches WebKit", %{assets: assets} do
      {_session, browser} = Playwright.BrowserType.launch(:webkit)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
      Playwright.Browser.close(browser)
    end
  end
end
