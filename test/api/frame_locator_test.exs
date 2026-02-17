defmodule Playwright.FrameLocatorTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Locator, Page}
  alias Playwright.Page.FrameLocator

  describe "Page.frame_locator/2" do
    test "locates elements inside an iframe", %{page: page, assets: assets} do
      Page.goto(page, assets.prefix <> "/frames/one-frame.html")
      locator = page |> Page.frame_locator("iframe") |> FrameLocator.locator("div")
      assert Locator.text_content(locator) =~ "Hi, I'm frame"
    end
  end

  describe "FrameLocator.get_by_text/3" do
    test "finds elements by text inside iframe", %{page: page, assets: assets} do
      Page.goto(page, assets.prefix <> "/frames/one-frame.html")
      fl = Page.frame_locator(page, "iframe")
      locator = FrameLocator.get_by_text(fl, "Hi, I'm frame")
      assert Locator.count(locator) == 1
    end
  end

  describe "FrameLocator.owner/1" do
    test "returns locator for the iframe element itself", %{page: page, assets: assets} do
      Page.goto(page, assets.prefix <> "/frames/one-frame.html")
      fl = Page.frame_locator(page, "iframe")
      owner = FrameLocator.owner(fl)
      assert Locator.evaluate(owner, "e => e.tagName") == "IFRAME"
    end
  end

  describe "FrameLocator.frame_locator/2" do
    test "supports nested frame locators", %{page: page} do
      Page.set_content(page, """
      <iframe id="outer" srcdoc="<iframe id='inner' srcdoc='<div>nested content</div>'></iframe>"></iframe>
      """)

      # Give iframes time to load
      Page.wait_for_selector(page, "#outer")

      locator =
        page
        |> Page.frame_locator("#outer")
        |> FrameLocator.frame_locator("#inner")
        |> FrameLocator.locator("div")

      assert Locator.text_content(locator) =~ "nested content"
    end
  end

  describe "Locator.frame_locator/2" do
    test "creates frame locator from a locator", %{page: page, assets: assets} do
      Page.goto(page, assets.prefix <> "/frames/one-frame.html")

      locator =
        page
        |> Page.locator("body")
        |> Locator.frame_locator("iframe")
        |> FrameLocator.locator("div")

      assert Locator.text_content(locator) =~ "Hi, I'm frame"
    end
  end
end
