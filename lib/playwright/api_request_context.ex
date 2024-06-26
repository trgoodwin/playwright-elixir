defmodule Playwright.APIRequestContext do
  @moduledoc """
  This API is used for the Web API testing. You can use it to trigger API endpoints, configure micro-services,
  prepare environment or the server to your e2e test.

  Use this at caution as has not been tested.

  """

  use Playwright.SDK.ChannelOwner
  alias Playwright.APIRequestContext

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

  # @spec delete(t(), binary(), options()) :: APIResponse.t()
  # def delete(context, url, options \\ %{})

  # @spec dispose(t()) :: :ok
  # def dispose(api_request_context)

  # @spec fetch(t(), binary() | Request.t(), options()) :: APIResponse.t()
  # def fetch(context, url_or_request, options \\ %{})

  # @spec get(t(), binary(), options()) :: APIResponse.t()
  # def get(context, url, options \\ %{})

  # @spec head(t(), binary(), options()) :: APIResponse.t()
  # def head(context, url, options \\ %{})

  # @spec patch(t(), binary(), options()) :: APIResponse.t()
  # def patch(context, url, options \\ %{})

  @spec post(t(), binary(), fetch_options()) :: Playwright.APIResponse.t()
  def post(%APIRequestContext{session: session} = context, url, options \\ %{}) do
    Channel.post(
      session,
      {:guid, context.guid},
      :fetch,
      Map.merge(
        %{
          url: url,
          method: "POST"
        },
        options
      )
    )
  end

  # @spec put(t(), binary(), options()) :: APIResponse.t()
  # def put(context, url, options \\ %{})

  # @spec storage_state(t(), options()) :: StorageState.t()
  # def storage_state(context, options \\ %{})

  # TODO: move to `APIResponse.body`, probably.
  @spec body(t(), Playwright.APIResponse.t()) :: any()
  def body(%APIRequestContext{session: session} = context, response) do
    Channel.post(session, {:guid, context.guid}, :fetch_response_body, %{
      fetchUid: response.fetchUid
    })
  end
end
