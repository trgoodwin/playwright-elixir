defmodule Playwright.TracingTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, BrowserContext, Page, Tracing}

  describe "Tracing" do
    @tag exclude: [:page]
    test "start and stop tracing without saving", %{browser: browser, assets: assets} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Tracing.start(context, %{screenshots: true, snapshots: true})
      Page.goto(page, assets.empty)
      Tracing.stop(context)

      Page.close(page)
      BrowserContext.close(context)
    end

    @tag exclude: [:page]
    test "start and stop tracing with path", %{browser: browser, assets: assets} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Tracing.start(context, %{screenshots: true, snapshots: true})
      Page.goto(page, assets.empty)

      path = Path.join(System.tmp_dir!(), "trace-#{System.unique_integer([:positive])}.zip")
      Tracing.stop(context, %{path: path})

      assert File.exists?(path)

      Page.close(page)
      BrowserContext.close(context)

      File.rm(path)
    end

    @tag exclude: [:page]
    test "start and stop tracing via Tracing struct", %{browser: browser, assets: assets} do
      context = Browser.new_context(browser)
      tracing = BrowserContext.tracing(context)
      page = BrowserContext.new_page(context)

      Tracing.start(tracing, %{screenshots: true, snapshots: true})
      Page.goto(page, assets.empty)
      Tracing.stop(tracing)

      Page.close(page)
      BrowserContext.close(context)
    end

    @tag exclude: [:page]
    test "start_chunk and stop_chunk", %{browser: browser, assets: assets} do
      context = Browser.new_context(browser)
      page = BrowserContext.new_page(context)

      Tracing.start(context, %{screenshots: true, snapshots: true})
      Page.goto(page, assets.empty)
      Tracing.stop_chunk(context)

      Tracing.start_chunk(context)
      Page.goto(page, assets.empty)
      Tracing.stop_chunk(context)

      Tracing.stop(context)

      Page.close(page)
      BrowserContext.close(context)
    end
  end
end
