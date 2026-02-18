defmodule Playwright.JSHandleTest do
  use Playwright.TestCase, async: true
  alias Playwright.{ElementHandle, JSHandle, Page}

  describe "JSHandle.as_element/1" do
    test "returns `nil` for non-elements", %{page: page} do
      handle = Page.evaluate_handle(page, "function() { return 2; }")
      result = JSHandle.as_element(handle)
      refute result
    end

    test "returns an ElementHandle for DOM elements", %{page: page} do
      handle = Page.evaluate_handle(page, "function() { return document.body; }")
      result = JSHandle.as_element(handle)
      assert is_struct(result, ElementHandle)
    end

    # NOTE: review description
    test "returns an ElementHandle for DOM elements (take 2)", %{page: page} do
      handle = Page.evaluate_handle(page, "document.body")
      result = JSHandle.as_element(handle)
      assert is_struct(result, ElementHandle)
    end

    test "returns an ElementHandle for text nodes", %{page: page} do
      Page.set_content(page, "<div>lala!</div>")
      handle = Page.evaluate_handle(page, "function() { return document.querySelector('div').firstChild; }")
      result = JSHandle.as_element(handle)
      assert is_struct(result, ElementHandle)

      assert Page.evaluate(page, "function(e) { return e.nodeType === Node.TEXT_NODE; }", result) == true
    end
  end

  describe "JSHandle.dispose/1" do
    test "disposes a handle", %{page: page} do
      handle = Page.evaluate_handle(page, "() => ({ a: 1 })")
      assert :ok = JSHandle.dispose(handle)
    end
  end

  describe "JSHandle.json_value/1" do
    test "returns the JSON value of a handle", %{page: page} do
      handle = Page.evaluate_handle(page, "() => ({ a: 1, b: 'two' })")
      result = JSHandle.json_value(handle)
      assert result == %{a: 1, b: "two"}
    end

    test "returns primitive values", %{page: page} do
      handle = Page.evaluate_handle(page, "() => 42")
      assert JSHandle.json_value(handle) == 42
    end
  end

  describe "JSHandle.get_properties/1" do
    test "returns properties of the handle", %{page: page} do
      handle = Page.evaluate_handle(page, "() => ({ foo: 'bar' })")
      result = JSHandle.get_properties(handle)
      assert is_list(result) or is_map(result)
    end
  end
end
