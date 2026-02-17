defmodule Playwright.WebErrorTest do
  use Playwright.TestCase, async: true

  test "exports error/1 and page/1" do
    Code.ensure_loaded!(Playwright.WebError)
    assert function_exported?(Playwright.WebError, :error, 1)
    assert function_exported?(Playwright.WebError, :page, 1)
  end
end
