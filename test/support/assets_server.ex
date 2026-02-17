defmodule Playwright.Test.AssetsServer do
  @moduledoc false
  use Plug.Router
  require Plug.Builder

  @fixtures_dir Path.expand("../fixtures", __DIR__)

  plug(:match)
  plug(:dispatch)

  get("/") do
    send_resp(conn, 200, "Serving Playwright assets")
  end

  match("/:root/:file") do
    respond_with(conn, "#{root}/#{file}")
  end

  match("/:root/:path/:file") do
    respond_with(conn, "#{root}/#{path}/#{file}")
  end

  match _ do
    send_resp(conn, 404, "404")
  end

  defp respond_with(conn, path) do
    fixtures_dir = @fixtures_dir

    case File.read(Path.join(fixtures_dir, path)) do
      {:error, :enoent} ->
        send_resp(conn, 404, "404")

      {:ok, body} ->
        conn = put_resp_header(conn, "x-playwright-request-method", conn.method)

        conn =
          if String.ends_with?(path, ".json"),
            do: put_resp_header(conn, "content-type", "application/json"),
            else: conn

        send_resp(conn, 200, body)
    end
  end
end
