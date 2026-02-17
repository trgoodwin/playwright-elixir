defmodule Playwright.SelectorsTest do
  use Playwright.TestCase, async: true

  alias Playwright.Selectors

  describe "Selectors module" do
    test "exports register/4" do
      Code.ensure_loaded!(Selectors)
      assert function_exported?(Selectors, :register, 4)
    end

    test "exports set_test_id_attribute/2" do
      Code.ensure_loaded!(Selectors)
      assert function_exported?(Selectors, :set_test_id_attribute, 2)
    end
  end
end
