defmodule Playwright.APIResponse do
  @moduledoc false
  use Playwright.SDK.ChannelOwner
  alias Playwright.APIResponse

  @property :fetchUid
  @property :headers
  @property :status
  @property :status_text
  @property :url

  @doc """
  Returns the response body as a binary.
  """
  @spec body(t()) :: binary()
  def body(%APIResponse{session: session} = response) do
    context = find_request_context(response)

    case Channel.post(session, {:guid, context.guid}, :fetch_response_body, %{fetchUid: response.fetchUid}) do
      nil -> ""
      data when is_binary(data) -> Base.decode64!(data)
      other -> other
    end
  end

  @doc """
  Returns the response body as text.
  """
  @spec text(t()) :: binary()
  def text(%APIResponse{} = response) do
    body(response)
  end

  @doc """
  Returns the response body parsed as JSON.
  """
  @spec json(t()) :: any()
  def json(%APIResponse{} = response) do
    text(response) |> Jason.decode!()
  end

  @doc """
  Returns the response headers as a list of `%{name: name, value: value}` maps.
  """
  @spec headers_array(t()) :: [map()]
  def headers_array(%APIResponse{} = response) do
    response = Channel.find(response.session, {:guid, response.guid})

    (response.headers || [])
    |> Enum.map(fn
      %{name: _, value: _} = h -> h
      {k, v} -> %{name: to_string(k), value: to_string(v)}
    end)
  end

  @doc """
  Disposes of the response body. It is an error to access the body after disposal.
  """
  @spec dispose(t()) :: :ok
  def dispose(%APIResponse{session: session} = response) do
    context = find_request_context(response)
    Channel.post(session, {:guid, context.guid}, :dispose_api_response, %{fetchUid: response.fetchUid})
    :ok
  end

  @spec ok(t()) :: boolean()
  def ok(%APIResponse{} = response) do
    response.status === 0 || (response.status >= 200 && response.status <= 299)
  end

  # private
  # ---------------------------------------------------------------------------

  defp find_request_context(%APIResponse{session: session, parent: parent}) do
    Channel.find(session, {:guid, parent.guid})
  end
end
