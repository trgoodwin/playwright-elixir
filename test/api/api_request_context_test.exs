defmodule Playwright.APIRequestContextTest do
  use Playwright.TestCase, async: true

  alias Playwright.APIRequestContext

  describe "APIRequestContext module" do
    test "exports get/3" do
      assert function_exported?(APIRequestContext, :get, 3)
    end

    test "exports post/3" do
      assert function_exported?(APIRequestContext, :post, 3)
    end

    test "exports put/3" do
      assert function_exported?(APIRequestContext, :put, 3)
    end

    test "exports patch/3" do
      assert function_exported?(APIRequestContext, :patch, 3)
    end

    test "exports delete/3" do
      assert function_exported?(APIRequestContext, :delete, 3)
    end

    test "exports head/3" do
      assert function_exported?(APIRequestContext, :head, 3)
    end

    test "exports fetch/3" do
      assert function_exported?(APIRequestContext, :fetch, 3)
    end

    test "exports dispose/1" do
      assert function_exported?(APIRequestContext, :dispose, 1)
    end

    test "exports storage_state/2" do
      assert function_exported?(APIRequestContext, :storage_state, 2)
    end

    test "exports body/2" do
      assert function_exported?(APIRequestContext, :body, 2)
    end
  end
end
