defmodule Playwright.WorkerTest do
  use Playwright.TestCase, async: true

  alias Playwright.{Page, Worker}

  describe "Worker.url/1" do
    test "returns the worker URL", %{assets: assets, page: page} do
      test_pid = self()

      Page.on(page, :worker, fn %{params: %{worker: worker}} ->
        send(test_pid, {:worker, worker})
      end)

      Page.goto(page, assets.prefix <> "/worker/worker.html")

      assert_receive {:worker, worker}, 5_000
      assert Worker.url(worker) =~ "/worker/worker.js"
    end
  end

  describe "Worker.evaluate/3" do
    test "evaluates an expression in the worker", %{assets: assets, page: page} do
      test_pid = self()

      Page.on(page, :worker, fn %{params: %{worker: worker}} ->
        send(test_pid, {:worker, worker})
      end)

      Page.goto(page, assets.prefix <> "/worker/worker.html")

      assert_receive {:worker, worker}, 5_000

      result = Worker.evaluate(worker, "() => 1 + 2")
      assert result == 3
    end

    test "evaluates a function with arguments", %{assets: assets, page: page} do
      test_pid = self()

      Page.on(page, :worker, fn %{params: %{worker: worker}} ->
        send(test_pid, {:worker, worker})
      end)

      Page.goto(page, assets.prefix <> "/worker/worker.html")

      assert_receive {:worker, worker}, 5_000

      result = Worker.evaluate(worker, "(x) => x * 2", 5)
      assert result == 10
    end
  end

  describe "Worker.evaluate_handle/3" do
    test "returns a handle", %{assets: assets, page: page} do
      test_pid = self()

      Page.on(page, :worker, fn %{params: %{worker: worker}} ->
        send(test_pid, {:worker, worker})
      end)

      Page.goto(page, assets.prefix <> "/worker/worker.html")

      assert_receive {:worker, worker}, 5_000

      handle = Worker.evaluate_handle(worker, "() => ({ answer: 42 })")
      assert %Playwright.JSHandle{} = handle
    end
  end

  describe "Worker.on/3" do
    test "registers a callback for :close", %{assets: assets, page: page} do
      test_pid = self()

      Page.on(page, :worker, fn %{params: %{worker: worker}} ->
        Worker.on(worker, :close, fn _event ->
          send(test_pid, :worker_closed)
        end)

        send(test_pid, {:worker, worker})
      end)

      Page.goto(page, assets.prefix <> "/worker/worker.html")
      assert_receive {:worker, _worker}, 5_000

      # Navigate away to close the worker
      Page.goto(page, "about:blank")
      assert_receive :worker_closed, 5_000
    end
  end
end
