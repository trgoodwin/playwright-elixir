defmodule Playwright.RouteTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, Route}

  describe "Route.abort/2" do
    test "aborts a request with default error code", %{assets: assets, page: page} do
      Page.route(page, "**/empty.html", fn route, _request ->
        Route.abort(route)
      end)

      result = Page.goto(page, assets.prefix <> "/empty.html")
      assert result == nil or match?({:error, _}, result)
    end

    test "aborts a request with a specific error code", %{assets: assets, page: page} do
      Page.route(page, "**/empty.html", fn route, _request ->
        Route.abort(route, "connectionrefused")
      end)

      result = Page.goto(page, assets.prefix <> "/empty.html")
      assert result == nil or match?({:error, _}, result)
    end
  end

  describe "Route.fallback/2" do
    test "falls through to next handler", %{assets: assets, page: page} do
      Page.route(page, "**/empty.html", fn route, _request ->
        Route.continue(route)
      end)

      Page.route(page, "**/empty.html", fn route, _request ->
        Route.fallback(route)
      end)

      response = Page.goto(page, assets.prefix <> "/empty.html")
      refute is_nil(response)
    end
  end
end
