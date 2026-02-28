defmodule Playwright.Route do
  @moduledoc """
  ...
  """
  use Playwright.SDK.ChannelOwner
  alias Playwright.Route

  @type options :: map()

  @property :request

  # ---

  @spec abort(t(), binary()) :: :ok
  def abort(route, error_code \\ "failed")

  def abort(%Route{session: session} = route, error_code) do
    table = Channel.Session.catalog_table(session)
    request = Channel.Catalog.get(table, route.request.guid)
    Channel.post(session, {:guid, route.guid}, :abort, %{error_code: error_code, request_url: request.url})
    :ok
  end

  # ---

  @spec continue(t(), options()) :: :ok
  def continue(route, options \\ %{})

  # TODO: figure out what's up with `is_fallback`.
  def continue(%Route{session: session} = route, options) do
    # HACK to deal with changes in v1.33.0
    table = Channel.Session.catalog_table(session)
    request = Channel.Catalog.get(table, route.request.guid)
    params = Map.merge(options, %{is_fallback: false, request_url: request.url})
    Channel.post(session, {:guid, route.guid}, :continue, params)
  end

  # ---

  @spec fallback(t(), options()) :: :ok
  def fallback(route, options \\ %{})

  def fallback(%Route{session: session} = route, options) do
    table = Channel.Session.catalog_table(session)
    request = Channel.Catalog.get(table, route.request.guid)
    params = Map.merge(options, %{is_fallback: true, request_url: request.url})
    Channel.post(session, {:guid, route.guid}, :continue, params)
    :ok
  end

  # ---

  @spec fetch(t(), options()) :: map()
  def fetch(route, options \\ %{})

  def fetch(%Route{session: session} = route, options) do
    table = Channel.Session.catalog_table(session)
    request = Channel.Catalog.get(table, route.request.guid)

    params = Map.merge(%{request_url: request.url}, options)

    params =
      if Map.has_key?(params, :headers) do
        %{params | headers: serialize_headers(params.headers)}
      else
        params
      end

    Channel.post(session, {:guid, route.guid}, :fetch, params)
  end

  # ---

  @spec fulfill(t(), options()) :: :ok
  # def fulfill(route, options \\ %{})

  def fulfill(%Route{session: session} = route, %{status: status, body: body}) when is_binary(body) do
    length = String.length(body)

    # HACK to deal with changes in v1.33.0
    table = Channel.Session.catalog_table(session)
    request = Channel.Catalog.get(table, route.request.guid)

    params = %{
      body: body,
      is_base64: false,
      length: length,
      request_url: request.url,
      status: status,
      headers:
        serialize_headers(%{
          "content-length" => "#{length}"
        })
    }

    Channel.post(session, {:guid, route.guid}, :fulfill, params)
  end

  # ---

  # @spec request(t()) :: Request.t()
  # def request(route)

  # ---

  # private
  # ---------------------------------------------------------------------------

  defp serialize_headers(headers) when is_map(headers) do
    Enum.reduce(headers, [], fn {k, v}, acc ->
      [%{name: k, value: v} | acc]
    end)
  end
end
