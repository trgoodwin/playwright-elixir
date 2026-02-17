defmodule Playwright.Page.LifecycleTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, Page}

  describe "Page.bring_to_front/1" do
    test "does not error", %{page: page} do
      assert Page.bring_to_front(page) == :ok
    end
  end

  describe "Page.is_closed/1" do
    @tag exclude: [:page]
    test "returns false for open page", %{browser: browser} do
      page = Browser.new_page(browser)
      refute Page.is_closed(page)
      Page.close(page)
    end

    @tag exclude: [:page]
    test "returns true after page is closed", %{browser: browser} do
      page = Browser.new_page(browser)
      Page.close(page)
      assert Page.is_closed(page)
    end
  end

  describe "Page.emulate_media/2" do
    test "emulates media type", %{page: page} do
      assert Page.emulate_media(page, %{media: "print"}) == :ok
    end

    test "emulates color scheme", %{page: page} do
      assert Page.emulate_media(page, %{color_scheme: "dark"}) == :ok
    end
  end

  describe "Page.viewport_size/1" do
    test "returns viewport dimensions", %{page: page} do
      size = Page.viewport_size(page)
      assert size == nil or (is_map(size) and Map.has_key?(size, :width))
    end
  end

  describe "Page.opener/1" do
    test "returns nil when there is no opener", %{page: page} do
      assert Page.opener(page) == nil
    end
  end
end
