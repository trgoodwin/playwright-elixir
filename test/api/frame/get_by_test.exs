defmodule Playwright.Frame.GetByTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Frame, Locator, Page}

  describe "Frame.get_by_role/3" do
    test "finds element by role", %{page: page} do
      Page.set_content(page, "<button>Submit</button><button>Cancel</button>")
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_role(:button, %{name: "Submit"}) |> Locator.count() == 1
    end

    test "finds element by role with exact option", %{page: page} do
      Page.set_content(page, "<button>Submit Order</button><button>Submit</button>")
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_role(:button, %{name: "Submit", exact: true}) |> Locator.count() == 1
    end
  end

  describe "Frame.get_by_label/3" do
    test "finds element by label", %{page: page} do
      Page.set_content(page, "<label for=\"username\">Username</label><input id=\"username\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_label(frame, "Username")
      assert Locator.count(locator) == 1
    end
  end

  describe "Frame.get_by_placeholder/3" do
    test "finds element by placeholder", %{page: page} do
      Page.set_content(page, "<input placeholder=\"Enter your name\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_placeholder(frame, "Enter your name")
      assert Locator.count(locator) == 1
    end
  end

  describe "Frame.get_by_alt_text/3" do
    test "finds element by alt text", %{page: page} do
      Page.set_content(page, "<img alt=\"Company Logo\" src=\"logo.png\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_alt_text(frame, "Company Logo")
      assert Locator.count(locator) == 1
    end
  end

  describe "Frame.get_by_title/3" do
    test "finds element by title attribute", %{page: page} do
      Page.set_content(page, "<span title=\"Help Text\">?</span>")
      frame = Page.main_frame(page)
      locator = Frame.get_by_title(frame, "Help Text")
      assert Locator.count(locator) == 1
    end
  end

  describe "Frame.get_by_test_id/2" do
    test "finds element by data-testid", %{page: page} do
      Page.set_content(page, "<div data-testid=\"user-profile\">Profile</div>")
      frame = Page.main_frame(page)
      locator = Frame.get_by_test_id(frame, "user-profile")
      assert Locator.count(locator) == 1
    end
  end
end
