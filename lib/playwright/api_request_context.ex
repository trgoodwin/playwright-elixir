defmodule Playwright.APIRequestContext do
  @moduledoc """
  This API is used for the Web API testing. You can use it to trigger API endpoints, configure micro-services,
  prepare environment or the server to your e2e test.

  Use this at caution as has not been tested.

  """

  use Playwright.SDK.ChannelOwner
  alias Playwright.APIRequestContext

  @typedoc "A map/struct providing call options"
  @type options :: map()

  @type fetch_options() :: %{
          optional(:params) => any(),
          optional(:method) => binary(),
          optional(:headers) => any(),
          optional(:postData) => any(),
          optional(:jsonData) => any(),
          optional(:formData) => any(),
          optional(:multipartData) => any(),
          optional(:timeout) => non_neg_integer(),
          optional(:failOnStatusCode) => boolean(),
          optional(:ignoreHTTPSErrors) => boolean()
        }

  @spec delete(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def delete(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "DELETE"}, options))
  end

  @spec dispose(t()) :: :ok
  def dispose(%APIRequestContext{session: session} = context) do
    Channel.post(session, {:guid, context.guid}, :dispose)
    :ok
  end

  @spec fetch(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def fetch(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    method = Map.get(options, :method, "GET")
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: method}, options))
  end

  @spec get(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def get(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "GET"}, options))
  end

  @spec head(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def head(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "HEAD"}, options))
  end

  @spec patch(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def patch(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "PATCH"}, options))
  end

  @spec post(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def post(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "POST"}, options))
  end

  @spec put(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def put(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :fetch, Map.merge(%{url: url, method: "PUT"}, options))
  end

  @spec storage_state(t(), options()) :: map()
  def storage_state(%APIRequestContext{session: session} = context, options \\ %{}) do
    Channel.post(session, {:guid, context.guid}, :storage_state, options)
  end

  # TODO: move to `APIResponse.body`, probably.
  @spec body(t(), Playwright.APIResponse.t()) :: any()
  def body(%APIRequestContext{session: session} = context, response) do
    Channel.post(session, {:guid, context.guid}, :fetch_response_body, %{
      fetchUid: response.fetchUid
    })
  end
end
