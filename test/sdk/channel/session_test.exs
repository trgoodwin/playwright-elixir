defmodule Playwright.SDK.Channel.SessionTest do
  use Playwright.TestCase, async: true
  alias Playwright.{Browser, Page}
  alias Playwright.SDK.Channel.Session

  describe "Session supervision" do
    test "children are managed by a Supervisor", %{page: page} do
      state = :sys.get_state(page.session)

      assert is_pid(state.supervisor)
      assert Process.alive?(state.supervisor)

      children = Supervisor.which_children(state.supervisor)
      child_ids = Enum.map(children, fn {id, _, _, _} -> id end) |> Enum.sort()

      assert Playwright.SDK.Channel.Catalog in child_ids
      assert Playwright.SDK.Channel.Connection in child_ids
      assert :task_supervisor in child_ids
    end

    test "all children are alive and match session state", %{page: page} do
      state = :sys.get_state(page.session)
      children_map = for {id, pid, _, _} <- Supervisor.which_children(state.supervisor), into: %{}, do: {id, pid}

      assert children_map[Playwright.SDK.Channel.Catalog] == state.catalog
      assert children_map[Playwright.SDK.Channel.Connection] == state.connection
      assert children_map[:task_supervisor] == state.task_supervisor

      for {_id, pid} <- children_map do
        assert Process.alive?(pid)
      end
    end

    test "supervisor counts match expected children", %{page: page} do
      state = :sys.get_state(page.session)
      counts = Supervisor.count_children(state.supervisor)

      assert counts[:active] == 3
      assert counts[:workers] == 2
      assert counts[:supervisors] == 1
    end
  end

  describe "binding cleanup on dispose" do
    @tag exclude: [:page]
    test "closing a page removes its bindings", %{browser: browser} do
      page = Browser.new_page(browser)
      session = page.session
      guid = page.guid

      # Register both sync and async bindings for the page
      Page.on(page, :close, fn _event -> :noop end)
      Session.bind(session, {guid, :custom_event}, fn _ -> :noop end)

      # Allow casts to process
      _ = Session.bindings(session)

      # Verify bindings exist
      bindings = Session.bindings(session)
      async_bindings = Session.async_bindings(session)
      assert Map.has_key?(bindings, {guid, :custom_event})
      assert Map.has_key?(async_bindings, {guid, :close})

      # Close the page — triggers __dispose__ which should clean up bindings
      Page.close(page)

      # Allow unbind_all casts to process
      Process.sleep(100)

      # Bindings for the disposed page should be gone
      bindings = Session.bindings(session)
      async_bindings = Session.async_bindings(session)

      page_bindings = Map.filter(bindings, fn {{g, _}, _} -> g == guid end)
      page_async = Map.filter(async_bindings, fn {{g, _}, _} -> g == guid end)

      assert page_bindings == %{}, "sync bindings for disposed page should be empty"
      assert page_async == %{}, "async bindings for disposed page should be empty"
    end
  end
end
