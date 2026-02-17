defmodule Playwright.Response do
  @moduledoc """
  ...
  """
  use Playwright.SDK.ChannelOwner
  alias Playwright.Response

  @property :frame
  @property :headers
  @property :request
  @property :status
  @property :status_text
  @property :url

  # API call
  # ---------------------------------------------------------------------------

  # ---

  @spec all_headers(t()) :: map()
  def all_headers(%Response{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :raw_response_headers)
    |> headers_to_map()
  end

  # ---

  @spec body(t()) :: binary()
  def body(%Response{session: session} = response) do
    Channel.post(session, {:guid, response.guid}, :body)
    |> Base.decode64!()
  end

  # ---

  # @spec finished(t()) :: :ok | {:error, SomeError.t()}
  # def finished(response)

  # @spec frame(Response.t()) :: Frame.t()
  # def frame(response)

  # @spec from_service_worker(Response.t()) :: boolean()
  # def from_service_worker(response)

  # ---

  @spec header_value(t(), binary()) :: binary() | nil
  def header_value(response, name) do
    headers = all_headers(response)
    Map.get(headers, String.downcase(name))
  end

  # ---

  @spec header_values(t(), binary()) :: [binary()]
  def header_values(%Response{session: session, guid: guid}, name) do
    headers = Channel.post(session, {:guid, guid}, :raw_response_headers)
    name_lower = String.downcase(name)

    headers
    |> Enum.filter(fn h -> String.downcase(h.name) == name_lower end)
    |> Enum.map(fn h -> h.value end)
  end

  # ---

  @spec headers_array(t()) :: [map()]
  def headers_array(%Response{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :raw_response_headers)
  end

  # ---

  @spec json(t()) :: any()
  def json(response) do
    body(response) |> Jason.decode!()
  end

  # ---

  @spec ok(t()) :: boolean()
  def ok(%Response{} = response) do
    response.status === 0 || (response.status >= 200 && response.status <= 299)
  end

  @spec ok({t(), t()}) :: boolean()
  def ok({:error, %Playwright.SDK.Channel.Error{}}) do
    false
  end

  # ---

  # @spec request(t()) :: Request.t()
  # def request(response)

  # ---

  @spec security_details(t()) :: map() | nil
  def security_details(%Response{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :security_details)
  end

  # ---

  @spec server_addr(t()) :: map() | nil
  def server_addr(%Response{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :server_addr)
  end

  # ---

  # @spec status(t()) :: number()
  # def status(response)

  # @spec status_text(t()) :: binary()
  # def status_text(response)

  # ---

  @spec text(t()) :: binary()
  def text(response) do
    body(response)
  end

  # ---

  # @spec url(t()) :: binary()
  # def url(response)

  # private
  # ---------------------------------------------------------------------------

  defp headers_to_map(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn header, acc ->
      Map.put(acc, String.downcase(header.name), header.value)
    end)
  end
end
