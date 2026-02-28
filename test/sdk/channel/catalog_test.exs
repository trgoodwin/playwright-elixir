defmodule Plawyeright.Channel.CatalogTest do
  use ExUnit.Case, async: true
  alias Playwright.SDK.Channel.{Catalog, Error}

  setup do
    catalog = start_supervised!({Catalog, %{guid: "Root"}})
    table = Catalog.table(catalog)
    %{catalog: catalog, table: table}
  end

  describe "Catalog.get/2" do
    test "returns an existing resource by `param: guid`", %{table: table} do
      assert Catalog.get(table, "Root") == %{guid: "Root"}
    end

    test "returns an awaited resource by `param: guid`", %{catalog: catalog, table: table} do
      Task.start(fn ->
        :timer.sleep(100)
        Catalog.put(table, catalog, %{guid: "Addition"})
      end)

      assert Catalog.get(table, "Addition") == %{guid: "Addition"}
    end

    test "returns an Error when there is no match within the timeout period", %{table: table} do
      assert {:error, %Error{message: "Timeout 50ms exceeded."}} = Catalog.get(table, "Missing", %{timeout: 50})
    end
  end

  describe "Catalog.list/2" do
    test "returns a List of resources that match the filter", %{table: table} do
      assert [%{guid: "Root"}] = Catalog.list(table, %{guid: "Root"})
    end

    test "filters by parent struct and type", %{catalog: catalog, table: table} do
      root = Catalog.get(table, "Root")
      Catalog.put(table, catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(table, catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})
      Catalog.put(table, catalog, %{guid: "C", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(table, %{parent: root, type: "Page"})
      assert [%{guid: "A"}] = result
    end

    test "filters by parent string GUID and type", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(table, catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})
      Catalog.put(table, catalog, %{guid: "C", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(table, %{parent: "Root", type: "Page"})
      assert [%{guid: "A"}] = result

      result = Catalog.list(table, %{parent: "Root", type: "Frame"})
      assert [%{guid: "B"}] = result

      result = Catalog.list(table, %{parent: "A", type: "Frame"})
      assert [%{guid: "C"}] = result
    end

    test "filters by parent string GUID without type", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(table, catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})

      result = Catalog.list(table, %{parent: "Root"})
      guids = Enum.map(result, & &1.guid) |> Enum.sort()
      assert guids == ["A", "B"]
    end

    test "does not return items from a different parent", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(table, catalog, %{guid: "B", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(table, %{parent: "Root", type: "Frame"})
      assert result == []
    end
  end

  describe "Catalog.put/2" do
    test "adds a resource to the catalog", %{catalog: catalog, table: table} do
      resource = %{guid: "Addition"}
      assert ^resource = Catalog.put(table, catalog, resource)
      assert ^resource = Catalog.get(table, "Addition")
    end
  end

  describe "terminate/2" do
    test "replies {:error, :terminated} to awaiting callers on shutdown", %{table: table} do
      task =
        Task.async(fn ->
          Catalog.get(table, "NonExistent", %{timeout: 5000})
        end)

      Process.sleep(50)
      stop_supervised(Catalog)

      assert {:error, :terminated} = Task.await(task, 1000)
    end

    test "replies {:error, :terminated} to watchers on shutdown", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "Watched"})

      task =
        Task.async(fn ->
          Catalog.watch(catalog, "Watched", fn _item -> false end, %{timeout: 5000})
        end)

      Process.sleep(50)
      stop_supervised(Catalog)

      assert {:error, :terminated} = Task.await(task, 1000)
    end
  end

  describe "Catalog.rm_r/2" do
    test "removes a resource and its descendants", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "Trunk", parent: %{guid: "Root"}})
      Catalog.put(table, catalog, %{guid: "Branch", parent: %{guid: "Trunk"}})
      Catalog.put(table, catalog, %{guid: "Leaf", parent: %{guid: "Branch"}})

      guids = :ets.tab2list(table) |> Enum.map(fn {guid, _} -> guid end) |> Enum.sort()
      assert guids == ["Branch", "Leaf", "Root", "Trunk"]

      :ok = Catalog.rm_r(table, "Trunk")

      guids = :ets.tab2list(table) |> Enum.map(fn {guid, _} -> guid end) |> Enum.sort()
      assert guids == ["Root"]
    end
  end

  describe "ETS direct reads" do
    test "get bypasses GenServer for existing items", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "Direct"})

      # Suspend the GenServer — if get went through it, this would hang
      :sys.suspend(catalog)
      assert %{guid: "Direct"} = Catalog.get(table, "Direct")
      :sys.resume(catalog)
    end

    test "list bypasses GenServer", %{catalog: catalog, table: table} do
      Catalog.put(table, catalog, %{guid: "X", parent: %{guid: "Root"}, type: "Page"})

      :sys.suspend(catalog)
      assert [%{guid: "X"}] = Catalog.list(table, %{parent: "Root", type: "Page"})
      :sys.resume(catalog)
    end
  end
end
