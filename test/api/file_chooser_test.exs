defmodule Playwright.FileChooserTest do
  use Playwright.TestCase, async: true

  alias Playwright.{ElementHandle, FileChooser, Page}

  describe "FileChooser" do
    test "captures file chooser event on click", %{page: page} do
      test_pid = self()

      Page.on(page, :file_chooser, fn %{params: params} ->
        send(test_pid, {:file_chooser, params})
      end)

      Page.set_content(page, "<input type='file' id='upload' />")
      Page.click(page, "#upload")

      assert_receive {:file_chooser, params}, 5_000
      assert %ElementHandle{} = params.element
      assert params.isMultiple == false
    end

    test "captures file chooser with multiple attribute", %{page: page} do
      test_pid = self()

      Page.on(page, :file_chooser, fn %{params: params} ->
        send(test_pid, {:file_chooser, params})
      end)

      Page.set_content(page, "<input type='file' id='upload' multiple />")
      Page.click(page, "#upload")

      assert_receive {:file_chooser, params}, 5_000
      assert params.isMultiple == true
    end

    test "FileChooser.from_event/2 builds a struct", %{page: page} do
      test_pid = self()

      Page.on(page, :file_chooser, fn %{params: params} ->
        fc = FileChooser.from_event(page, params)
        send(test_pid, {:file_chooser, fc})
      end)

      Page.set_content(page, "<input type='file' id='upload' />")
      Page.click(page, "#upload")

      assert_receive {:file_chooser, %FileChooser{} = fc}, 5_000
      assert %ElementHandle{} = FileChooser.element(fc)
      assert FileChooser.is_multiple(fc) == false
      assert %Page{} = FileChooser.page(fc)
    end

    test "FileChooser.set_files/2 uploads a file", %{assets: assets, page: page} do
      test_pid = self()
      fixture = "test/support/fixtures/file-to-upload.txt"

      Page.on(page, :file_chooser, fn %{params: params} ->
        fc = FileChooser.from_event(page, params)
        send(test_pid, {:file_chooser, fc})
      end)

      page |> Page.goto(assets.prefix <> "/input/fileupload.html")
      Page.click(page, "input[type=file]")

      assert_receive {:file_chooser, %FileChooser{} = fc}, 5_000
      FileChooser.set_files(fc, fixture)

      assert Page.evaluate(page, "e => e.files[0].name", FileChooser.element(fc)) == "file-to-upload.txt"
    end
  end
end
