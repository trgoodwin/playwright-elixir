defmodule Plawyeright.Channel.CatalogTest do
  use ExUnit.Case, async: true
  alias Playwright.SDK.Channel.{Catalog, Error}

  setup do
    %{
      catalog: start_supervised!({Catalog, %{guid: "Root"}})
    }
  end

  describe "Catalog.get/2" do
    test "returns an existing resource by `param: guid`", %{catalog: catalog} do
      assert Catalog.get(catalog, "Root") == %{guid: "Root"}
    end

    test "returns an awaited resource by `param: guid`", %{catalog: catalog} do
      Task.start(fn ->
        :timer.sleep(100)
        Catalog.put(catalog, %{guid: "Addition"})
      end)

      assert Catalog.get(catalog, "Addition") == %{guid: "Addition"}
    end

    test "returns an Error when there is no match within the timeout period", %{catalog: catalog} do
      assert {:error, %Error{message: "Timeout 50ms exceeded."}} = Catalog.get(catalog, "Missing", %{timeout: 50})
    end
  end

  describe "Catalog.list/2" do
    test "returns a List of resources that match the filter", %{catalog: catalog} do
      assert [%{guid: "Root"}] = Catalog.list(catalog, %{guid: "Root"})
    end

    test "filters by parent struct and type", %{catalog: catalog} do
      root = Catalog.get(catalog, "Root")
      Catalog.put(catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})
      Catalog.put(catalog, %{guid: "C", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(catalog, %{parent: root, type: "Page"})
      assert [%{guid: "A"}] = result
    end

    test "filters by parent string GUID and type", %{catalog: catalog} do
      Catalog.put(catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})
      Catalog.put(catalog, %{guid: "C", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(catalog, %{parent: "Root", type: "Page"})
      assert [%{guid: "A"}] = result

      result = Catalog.list(catalog, %{parent: "Root", type: "Frame"})
      assert [%{guid: "B"}] = result

      result = Catalog.list(catalog, %{parent: "A", type: "Frame"})
      assert [%{guid: "C"}] = result
    end

    test "filters by parent string GUID without type", %{catalog: catalog} do
      Catalog.put(catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(catalog, %{guid: "B", parent: %{guid: "Root"}, type: "Frame"})

      result = Catalog.list(catalog, %{parent: "Root"})
      guids = Enum.map(result, & &1.guid) |> Enum.sort()
      assert guids == ["A", "B"]
    end

    test "does not return items from a different parent", %{catalog: catalog} do
      Catalog.put(catalog, %{guid: "A", parent: %{guid: "Root"}, type: "Page"})
      Catalog.put(catalog, %{guid: "B", parent: %{guid: "A"}, type: "Frame"})

      result = Catalog.list(catalog, %{parent: "Root", type: "Frame"})
      assert result == []
    end
  end

  describe "Catalog.put/2" do
    test "adds a resource to the catalog", %{catalog: catalog} do
      resource = %{guid: "Addition"}
      assert ^resource = Catalog.put(catalog, resource)
      assert ^resource = Catalog.get(catalog, "Addition")
    end
  end

  describe "terminate/2" do
    test "replies {:error, :terminated} to awaiting callers on shutdown", %{catalog: catalog} do
      task =
        Task.async(fn ->
          Catalog.get(catalog, "NonExistent", %{timeout: 5000})
        end)

      Process.sleep(50)
      stop_supervised(Catalog)

      assert {:error, :terminated} = Task.await(task, 1000)
    end

    test "replies {:error, :terminated} to watchers on shutdown", %{catalog: catalog} do
      Catalog.put(catalog, %{guid: "Watched"})

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
    test "removes a resource and its descendants", %{catalog: catalog} do
      Catalog.put(catalog, %{guid: "Trunk", parent: %{guid: "Root"}})
      Catalog.put(catalog, %{guid: "Branch", parent: %{guid: "Trunk"}})
      Catalog.put(catalog, %{guid: "Leaf", parent: %{guid: "Branch"}})

      guids = Map.keys(:sys.get_state(catalog).storage)
      assert guids == ["Branch", "Leaf", "Root", "Trunk"]

      :ok = Catalog.rm_r(catalog, "Trunk")

      guids = Map.keys(:sys.get_state(catalog).storage)
      assert guids == ["Root"]
    end
  end
end
