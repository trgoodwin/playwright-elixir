defmodule Playwright.PlaywrightTest do
  use ExUnit.Case, async: true
  use PlaywrightTest.Case
  alias Playwright.{Browser, Page, Response}

  describe "Playwright.connect/2" do
    @tag :ws
    test "with :chromium" do
      with {:ok, browser} <- Playwright.connect(:chromium) do
        page = Browser.new_page(browser)

        assert page
               |> Page.goto("https://www.whatsmybrowser.org")
               |> Response.ok()

        assert Playwright.Page.text_content(page, "h2.header") =~ "Chrome"
      end
    end

    @tag :ws
    test "with :firefox" do
      with {:ok, browser} <- Playwright.connect(:firefox) do
        page = Browser.new_page(browser)

        assert page
               |> Page.goto("https://www.whatsmybrowser.org")
               |> Response.ok()

        assert Playwright.Page.text_content(page, "h2.header") =~ "Firefox"
      end
    end

    @tag :ws
    test "with :webkit" do
      with {:ok, browser} <- Playwright.connect(:webkit) do
        page = Browser.new_page(browser)

        assert page
               |> Page.goto("https://www.whatsmybrowser.org")
               |> Response.ok()

        assert Playwright.Page.text_content(page, "h2.header") =~ "Safari"
      end
    end
  end

  describe "Playwright.launch/1" do
    test "launches and returns an instance of the requested Browser" do
      {:ok, browser} = Playwright.launch(:chromium)

      assert browser
             |> Browser.new_page()
             |> Page.goto("http://example.com")
             |> Response.ok()
    end
  end

  describe "PlaywrightTest.Case context" do
    test "using `:browser`", %{browser: browser} do
      assert browser
             |> Browser.new_page()
             |> Page.goto("http://example.com")
             |> Response.ok()
    end

    test "with :firefox" do
      with {:ok, br} <- Playwright.launch(:firefox),
           {:ok, pg} <- Browser.new_page(br),
           {:ok, rs} <- Page.goto(pg, "https://www.whatsmybrowser.org") do
        assert Playwright.Response.ok(rs)
        assert Playwright.Page.text_content(pg, "h2.header") =~ "Firefox"
      end
      |> pass()
    end

    test "with :webkit" do
      with {:ok, br} <- Playwright.launch(:webkit),
           {:ok, pg} <- Browser.new_page(br),
           {:ok, rs} <- Page.goto(pg, "https://www.whatsmybrowser.org") do
        assert Playwright.Response.ok(rs)
        assert Playwright.Page.text_content(pg, "h2.header") =~ "Safari"
      end
      |> pass()
    end
  end
end
