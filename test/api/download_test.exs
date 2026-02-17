defmodule Playwright.DownloadTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, BrowserContext, Download, Page}

  describe "Download" do
    @tag exclude: [:page]
    test "captures download event and wraps it in a Download struct", %{browser: browser} do
      context = Browser.new_context(browser, %{accept_downloads: "accept"})
      page = BrowserContext.new_page(context)
      test_pid = self()

      Page.on(page, :download, fn %{params: params, target: target} ->
        download = Download.from_event(target, params)
        send(test_pid, {:download, download})
      end)

      Page.set_content(page, """
      <a download="test-file.txt" href="data:text/plain,hello world">Download</a>
      """)

      Page.click(page, "a")

      assert_receive {:download, %Download{} = download}, 10_000

      assert Download.suggested_filename(download) == "test-file.txt"
      assert Download.url(download) =~ "data:text/plain,hello world"
      assert %Page{} = Download.page(download)

      Page.close(page)
      BrowserContext.close(context)
    end

    @tag exclude: [:page]
    test "save_as saves the download to a file", %{browser: browser, assets: assets} do
      context = Browser.new_context(browser, %{accept_downloads: "accept"})
      page = BrowserContext.new_page(context)
      test_pid = self()

      Page.on(page, :download, fn %{params: params, target: target} ->
        download = Download.from_event(target, params)
        send(test_pid, {:download, download})
      end)

      Page.goto(page, assets.prefix <> "/download-blob.html")
      Page.click(page, "a")

      assert_receive {:download, %Download{} = download}, 10_000

      path = Path.join(System.tmp_dir!(), "playwright-download-test-#{:rand.uniform(100_000)}.txt")

      try do
        Download.save_as(download, path)
        assert File.exists?(path)
        assert File.read!(path) == "Hello world"
      after
        File.rm(path)
      end

      Page.close(page)
      BrowserContext.close(context)
    end

    @tag exclude: [:page]
    test "delete removes the downloaded artifact", %{browser: browser} do
      context = Browser.new_context(browser, %{accept_downloads: "accept"})
      page = BrowserContext.new_page(context)
      test_pid = self()

      Page.on(page, :download, fn %{params: params, target: target} ->
        download = Download.from_event(target, params)
        send(test_pid, {:download, download})
      end)

      Page.set_content(page, """
      <a download="delete-test.txt" href="data:text/plain,delete me">Download</a>
      """)

      Page.click(page, "a")

      assert_receive {:download, %Download{} = download}, 10_000
      assert :ok = Download.delete(download)

      Page.close(page)
      BrowserContext.close(context)
    end
  end
end
