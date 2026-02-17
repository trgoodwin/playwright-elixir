defmodule Playwright.Test.AssetsServer do
  @moduledoc false
  use Plug.Builder

  plug(Plug.Static, at: "/", from: Path.expand("../fixtures", __DIR__))

  plug(:not_found)

  defp not_found(conn, _opts) do
    send_resp(conn, 404, "404")
  end
end
