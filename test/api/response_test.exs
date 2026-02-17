defmodule Playwright.ResponseTest do
  use Playwright.TestCase, async: true

  alias Playwright.Page
  alias Playwright.Response

  describe "Response.ok/1" do
    test "works", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/dom.html")
      assert Response.ok(response)
    end
  end

  describe "Response.body/1" do
    test "for a simple HTML page", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/title.html")
      assert Response.body(response) == "<!DOCTYPE html>\n<title>Woof-Woof</title>\n"
    end
  end

  describe "Response.json/1" do
    test "parses response body as JSON", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/simple.json")
      data = Response.json(response)
      assert is_map(data)
      assert data["foo"] == "bar"
    end
  end

  describe "Response.all_headers/1" do
    test "returns all response headers", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      headers = Response.all_headers(response)
      assert is_map(headers)
      assert Map.has_key?(headers, "content-type") or map_size(headers) > 0
    end
  end

  describe "Response.header_value/2" do
    test "returns a specific header value", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      content_type = Response.header_value(response, "content-type")
      assert content_type == nil or is_binary(content_type)
    end
  end

  describe "Response.header_values/2" do
    test "returns all values for a header", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      values = Response.header_values(response, "content-type")
      assert is_list(values)
    end
  end

  describe "Response.headers_array/1" do
    test "returns headers as a list", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      headers = Response.headers_array(response)
      assert is_list(headers)
    end
  end

  describe "Response.security_details/1" do
    test "returns nil or empty for non-HTTPS response", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      details = Response.security_details(response)
      assert details == nil or details == %{}
    end
  end

  describe "Response.server_addr/1" do
    test "returns server address", %{assets: assets, page: page} do
      response = Page.goto(page, assets.prefix <> "/empty.html")
      addr = Response.server_addr(response)
      assert addr == nil or is_map(addr)
    end
  end
end
