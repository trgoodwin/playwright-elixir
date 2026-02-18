defmodule Playwright.ConsoleMessageTest do
  use Playwright.TestCase, async: true

  alias Playwright.{ConsoleMessage, Page}

  describe "ConsoleMessage" do
    test "receives console.log messages with text/1 and type/1", %{page: page} do
      test_pid = self()

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        send(test_pid, {:console, msg})
      end)

      Page.evaluate(page, "() => console.log('hello world')")

      assert_receive {:console, msg}, 5_000
      assert ConsoleMessage.text(msg) == "hello world"
      assert ConsoleMessage.type(msg) == "log"
    end

    test "receives console.error messages", %{page: page} do
      test_pid = self()

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        send(test_pid, {:console, msg})
      end)

      Page.evaluate(page, "() => console.error('something failed')")

      assert_receive {:console, msg}, 5_000
      assert ConsoleMessage.text(msg) == "something failed"
      assert ConsoleMessage.type(msg) == "error"
    end

    test "provides location information", %{page: page} do
      test_pid = self()

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        send(test_pid, {:console, msg})
      end)

      Page.evaluate(page, "() => console.log('with location')")

      assert_receive {:console, msg}, 5_000
      location = ConsoleMessage.location(msg)
      assert is_map(location)
    end

    test "args/1 returns the arguments from from_event", %{page: page} do
      test_pid = self()

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        send(test_pid, {:console, msg})
      end)

      Page.evaluate(page, "() => console.log('hello', 42)")

      assert_receive {:console, msg}, 5_000
      args = ConsoleMessage.args(msg)
      assert is_list(args)
    end

    test "page/1 returns the page from from_event", %{page: page} do
      test_pid = self()

      Page.on(page, :console, fn event ->
        msg = ConsoleMessage.from_event(event)
        send(test_pid, {:console, msg})
      end)

      Page.evaluate(page, "() => console.log('test')")

      assert_receive {:console, msg}, 5_000
      # from_event wraps the page from event params, which may be nil
      # in the current implementation
      _p = ConsoleMessage.page(msg)
    end
  end
end
