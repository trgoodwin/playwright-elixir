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

    test "finds all buttons without name filter", %{page: page} do
      Page.set_content(page, "<button>Submit</button><button>Cancel</button>")
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_role(:button) |> Locator.count() == 2
    end
  end

  describe "Frame.get_by_label/3" do
    test "finds element by label", %{page: page} do
      Page.set_content(page, "<label for=\"username\">Username</label><input id=\"username\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_label(frame, "Username")
      assert Locator.count(locator) == 1
    end

    test "finds element by label with exact match", %{page: page} do
      Page.set_content(page, """
      <label for="user">Username</label><input id="user" />
      <label for="other">Username Field</label><input id="other" />
      """)
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_label("Username", %{exact: true}) |> Locator.count() == 1
    end
  end

  describe "Frame.get_by_placeholder/3" do
    test "finds element by placeholder", %{page: page} do
      Page.set_content(page, "<input placeholder=\"Enter your name\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_placeholder(frame, "Enter your name")
      assert Locator.count(locator) == 1
    end

    test "finds element by placeholder with exact match", %{page: page} do
      Page.set_content(page, """
      <input placeholder="Enter your name" />
      <input placeholder="Enter your name here" />
      """)
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_placeholder("Enter your name", %{exact: true}) |> Locator.count() == 1
    end
  end

  describe "Frame.get_by_alt_text/3" do
    test "finds element by alt text", %{page: page} do
      Page.set_content(page, "<img alt=\"Company Logo\" src=\"logo.png\" />")
      frame = Page.main_frame(page)
      locator = Frame.get_by_alt_text(frame, "Company Logo")
      assert Locator.count(locator) == 1
    end

    test "finds element by alt text with exact match", %{page: page} do
      Page.set_content(page, """
      <img alt="Company Logo" src="a.png" />
      <img alt="Company Logo Large" src="b.png" />
      """)
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_alt_text("Company Logo", %{exact: true}) |> Locator.count() == 1
    end
  end

  describe "Frame.get_by_title/3" do
    test "finds element by title attribute", %{page: page} do
      Page.set_content(page, "<span title=\"Help Text\">?</span>")
      frame = Page.main_frame(page)
      locator = Frame.get_by_title(frame, "Help Text")
      assert Locator.count(locator) == 1
    end

    test "finds element by title with exact match", %{page: page} do
      Page.set_content(page, """
      <span title="Help Text">?</span>
      <span title="Help Text Extended">!</span>
      """)
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_title("Help Text", %{exact: true}) |> Locator.count() == 1
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
