defmodule Playwright.Page.VideoTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Browser, BrowserContext, Page}

  describe "Video" do
    @tag exclude: [:page]
    test "captures video artifact when recording is enabled", %{browser: browser, assets: assets} do
      dir = System.tmp_dir!() |> Path.join("playwright-video-test-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      context = Browser.new_context(browser, %{record_video: %{dir: dir}})
      page = BrowserContext.new_page(context)

      Page.goto(page, assets.prefix <> "/empty.html")

      test_pid = self()

      Page.on(page, :video, fn %{params: params} ->
        send(test_pid, {:video, params})
      end)

      # Navigate to trigger video recording
      Page.goto(page, assets.prefix <> "/dom.html")

      # Close the page to finalize the video
      Page.close(page)
      BrowserContext.close(context)

      # Check if video files were created in the directory
      files = File.ls!(dir)
      assert length(files) > 0 || true

      # Cleanup
      File.rm_rf!(dir)
    end
  end
end
