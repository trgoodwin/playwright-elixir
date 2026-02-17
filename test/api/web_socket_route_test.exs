defmodule Playwright.WebSocketRouteTest do
  use Playwright.TestCase, async: true

  test "exports url/1" do
    Code.ensure_loaded!(Playwright.WebSocketRoute)
    assert function_exported?(Playwright.WebSocketRoute, :url, 1)
  end
end
