defmodule Playwright.SDK.Channel.SessionTest do
  use Playwright.TestCase, async: true

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
end
