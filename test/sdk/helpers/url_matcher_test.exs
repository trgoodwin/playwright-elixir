defmodule Playwright.SDK.Helpers.URLMatcherTest do
  use ExUnit.Case, async: true
  alias Playwright.SDK.Helpers.URLMatcher

  describe "new/1" do
    test "returns a URLMatcher struct, with a compiled :regex" do
      %URLMatcher{regex: regex} = URLMatcher.new(".*/path")
      assert Regex.match?(regex, "http://example.com/path")
    end

    test "given a path-glob style match" do
      %URLMatcher{regex: regex} = URLMatcher.new("**/path")
      assert Regex.match?(regex, "http://example.com/path")
    end
  end
end
