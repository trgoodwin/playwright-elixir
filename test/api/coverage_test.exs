defmodule Playwright.CoverageTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, Coverage}

  describe "Coverage (Chromium only)" do
    test "start and stop JS coverage", %{page: page, assets: assets} do
      Coverage.start_js_coverage(page)
      Page.goto(page, assets.empty)
      entries = Coverage.stop_js_coverage(page)
      assert is_list(entries)
    end

    test "start and stop CSS coverage", %{page: page, assets: assets} do
      Coverage.start_css_coverage(page)
      Page.goto(page, assets.empty)
      entries = Coverage.stop_css_coverage(page)
      assert is_list(entries)
    end
  end
end
