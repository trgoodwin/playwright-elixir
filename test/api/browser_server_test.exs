defmodule Playwright.BrowserServerTest do
  use Playwright.TestCase, async: true

  test "exports close/1 and kill/1" do
    Code.ensure_loaded!(Playwright.BrowserServer)
    assert function_exported?(Playwright.BrowserServer, :close, 1)
    assert function_exported?(Playwright.BrowserServer, :kill, 1)
  end
end
