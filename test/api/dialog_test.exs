defmodule Playwright.DialogTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Dialog, Page}

  describe "Dialog" do
    test "accepts an alert dialog", %{page: page} do
      test_pid = self()

      Page.on(page, :dialog, fn %{params: %{dialog: dialog}} ->
        send(test_pid, {:dialog, dialog})
        Task.start(fn -> Dialog.accept(dialog) end)
      end)

      Page.evaluate(page, "() => alert('hello')")

      assert_receive {:dialog, dialog}, 5_000
      assert Dialog.type(dialog) == "alert"
      assert Dialog.message(dialog) == "hello"
    end

    test "dismisses a confirm dialog", %{page: page} do
      test_pid = self()

      Page.on(page, :dialog, fn %{params: %{dialog: dialog}} ->
        send(test_pid, {:dialog, dialog})
        Task.start(fn -> Dialog.dismiss(dialog) end)
      end)

      result = Page.evaluate(page, "() => confirm('are you sure?')")

      assert_receive {:dialog, dialog}, 5_000
      assert Dialog.type(dialog) == "confirm"
      assert Dialog.message(dialog) == "are you sure?"
      assert result == false
    end

    test "accepts a prompt dialog with text", %{page: page} do
      test_pid = self()

      Page.on(page, :dialog, fn %{params: %{dialog: dialog}} ->
        send(test_pid, {:dialog, dialog})
        Task.start(fn -> Dialog.accept(dialog, "my answer") end)
      end)

      result = Page.evaluate(page, "() => prompt('enter value', 'default')")

      assert_receive {:dialog, dialog}, 5_000
      assert Dialog.type(dialog) == "prompt"
      assert Dialog.message(dialog) == "enter value"
      assert Dialog.default_value(dialog) == "default"
      assert result == "my answer"
    end
  end
end
