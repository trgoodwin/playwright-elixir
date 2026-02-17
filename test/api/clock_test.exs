defmodule Playwright.ClockTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, BrowserContext, Clock, Page}

  describe "Clock.install/2 and Clock.set_fixed_time/2" do
    @tag exclude: [:page]
    test "installs clock and freezes time", %{browser: browser} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Clock.install(context, %{time: "2024-01-01T00:00:00Z"})

      time = Page.evaluate(page, "() => new Date().toISOString()")
      assert time =~ "2024-01-01"

      Clock.set_fixed_time(context, "2024-06-15T12:00:00Z")

      time = Page.evaluate(page, "() => new Date().toISOString()")
      assert time =~ "2024-06-15"

      Page.close(page)
      BrowserContext.close(context)
    end
  end

  describe "Clock.fast_forward/2" do
    @tag exclude: [:page]
    test "advances the clock by the given ticks", %{browser: browser} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Clock.install(context, %{time: "2024-01-01T00:00:00Z"})
      Clock.pause_at(context, "2024-01-01T00:00:00Z")
      Clock.fast_forward(context, 30_000)

      time = Page.evaluate(page, "() => new Date().toISOString()")
      assert time =~ "2024-01-01T00:00:30"

      Page.close(page)
      BrowserContext.close(context)
    end
  end

  describe "Clock.set_system_time/2" do
    @tag exclude: [:page]
    test "sets the system time", %{browser: browser} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Clock.install(context)

      Clock.set_system_time(context, "2030-12-25T00:00:00Z")

      time = Page.evaluate(page, "() => new Date().toISOString()")
      assert time =~ "2030-12-25"

      Page.close(page)
      BrowserContext.close(context)
    end
  end
end
