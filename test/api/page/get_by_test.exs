defmodule Playwright.Page.GetByTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Locator, Page}

  describe "Page.get_by_role/3" do
    test "finds element by role", %{page: page} do
      Page.set_content(page, "<button>Submit</button><button>Cancel</button>")
      assert page |> Page.get_by_role(:button, %{name: "Submit"}) |> Locator.count() == 1
    end
  end

  describe "Page.get_by_label/3" do
    test "finds element by label", %{page: page} do
      Page.set_content(page, "<label for=\"username\">Username</label><input id=\"username\" />")
      assert page |> Page.get_by_label("Username") |> Locator.count() == 1
    end
  end

  describe "Page.get_by_placeholder/3" do
    test "finds element by placeholder", %{page: page} do
      Page.set_content(page, "<input placeholder=\"Enter your name\" />")
      assert page |> Page.get_by_placeholder("Enter your name") |> Locator.count() == 1
    end
  end

  describe "Page.get_by_alt_text/3" do
    test "finds element by alt text", %{page: page} do
      Page.set_content(page, "<img alt=\"Company Logo\" src=\"logo.png\" />")
      assert page |> Page.get_by_alt_text("Company Logo") |> Locator.count() == 1
    end
  end

  describe "Page.get_by_title/3" do
    test "finds element by title", %{page: page} do
      Page.set_content(page, "<span title=\"Help Text\">?</span>")
      assert page |> Page.get_by_title("Help Text") |> Locator.count() == 1
    end
  end

  describe "Page.get_by_test_id/2" do
    test "finds element by data-testid", %{page: page} do
      Page.set_content(page, "<div data-testid=\"user-profile\">Profile</div>")
      assert page |> Page.get_by_test_id("user-profile") |> Locator.count() == 1
    end
  end
end
