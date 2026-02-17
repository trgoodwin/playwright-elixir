defmodule Playwright.NavigationTest do
  use Playwright.TestCase, async: true
  alias Playwright.{Page, Response}
  alias Playwright.SDK.Channel.Error

  describe "Page.goto/2" do
    test "works (and updates the page's URL)", %{assets: assets, page: page} do
      assert Page.url(page) == assets.blank

      Page.goto(page, assets.empty)
      assert Page.url(page) == assets.empty
    end

    test "works with anchor navigation", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      assert Page.url(page) == assets.empty

      Page.goto(page, assets.empty <> "#foo")
      assert Page.url(page) == assets.empty <> "#foo"

      Page.goto(page, assets.empty <> "#bar")
      assert Page.url(page) == assets.empty <> "#bar"
    end

    test "navigates to about:blank", %{assets: assets, page: page} do
      response = Page.goto(page, assets.blank)
      refute response
    end

    test "returns response when page changes its URL after load", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/historyapi.html")
      assert response.status == 200
    end

    # !!! works w/out implementation
    test "navigates to empty page with domcontentloaded", %{assets: assets, page: page} do
      response = Page.goto(page, assets.empty, %{wait_until: "domcontentloaded"})
      assert response.status == 200
    end

    test "works when page calls history API in beforeunload", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)

      Page.evaluate(page, """
      () => {
        window.addEventListener('beforeunload', () => history.replaceState(null, 'initial', window.location.href), false)
      }
      """)

      response = Page.goto(page, assets.prefix <> "/grid.html")
      assert response.status == 200
    end

    test "fails when navigating to bad URL", %{page: page} do
      error = %Error{
        type: "Error",
        message: "Protocol error (Page.navigate): Cannot navigate to invalid URL"
      }

      assert {:error, ^error} = Page.goto(page, "asdfasdf")
    end

    test "works when navigating to valid URL", %{assets: assets, page: page} do
      response = Page.goto(page, assets.empty)
      assert Response.ok(response)

      response = Page.goto(page, assets.empty)
      assert Response.ok(response)
    end
  end

  describe "Page.go_back/2" do
    test "navigates back in history", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      Page.goto(page, assets.dom)

      response = Page.go_back(page)
      assert is_nil(response) or is_struct(response, Response)

      assert Page.url(page) =~ "/empty.html"
    end

    test "returns nil when there is no history to go back", %{page: page} do
      response = Page.go_back(page)
      assert is_nil(response)
    end
  end

  describe "Page.go_forward/2" do
    test "navigates forward in history", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      Page.goto(page, assets.dom)

      Page.go_back(page)
      assert Page.url(page) =~ "/empty.html"

      response = Page.go_forward(page)
      assert is_nil(response) or is_struct(response, Response)

      assert Page.url(page) =~ "/dom.html"
    end

    test "returns nil when there is no history to go forward", %{page: page} do
      response = Page.go_forward(page)
      assert is_nil(response)
    end
  end

  describe "Page.wait_for_url/3" do
    test "resolves immediately when URL already matches", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      assert :ok = Page.wait_for_url(page, "/empty.html")
    end

    test "waits for navigation to the target URL", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)

      # Start a navigation in the background via JS
      Page.evaluate(page, "() => { setTimeout(() => window.location.href = '#{assets.dom}', 200) }")

      assert :ok = Page.wait_for_url(page, "/dom.html")
      assert Page.url(page) =~ "/dom.html"
    end
  end
end
