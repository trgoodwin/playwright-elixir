defmodule Playwright.RequestTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, Request, Response}

  describe "Request.response/1" do
    test "returns the response for a request", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      request = Response.request(response)
      resp = Request.response(request)
      assert resp != nil
      assert Response.status(resp) == 200
    end
  end

  describe "Request.all_headers/1" do
    test "returns all request headers", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      request = Response.request(response)
      headers = Request.all_headers(request)
      assert is_map(headers)
      # Browsers always send host header
      assert Map.has_key?(headers, "host")
    end
  end

  describe "Request.header_value/2" do
    test "returns a specific header value", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      request = Response.request(response)
      # user-agent should always be present
      assert Request.header_value(request, "user-agent") != nil
    end

    test "returns nil for missing header", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      request = Response.request(response)
      assert Request.header_value(request, "x-nonexistent-header") == nil
    end
  end

  describe "Request.headers_array/1" do
    test "returns headers as list of maps", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      request = Response.request(response)
      headers = Request.headers_array(request)
      assert is_list(headers)
      assert Enum.any?(headers, fn h -> String.downcase(h.name) == "host" end)
    end
  end
end
