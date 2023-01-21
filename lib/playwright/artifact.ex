defmodule Playwright.Artifact do
  use Playwright.ChannelOwner

  alias Playwright.Artifact
  alias Playwright.ChannelOwner

  @property :path

  @impl ChannelOwner
  def init(message, initializer) do
    {:ok, %{message | path: initializer.absolute_path}}
  end

  def save_as(%Artifact{session: session, guid: guid}, path) do
    Channel.post(session, {:guid, guid}, :save_as, %{path: path})
  end

  def delete(%Artifact{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :delete) |> IO.inspect()
  end

  def failure(%Artifact{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :failure) |> IO.inspect()
  end
end
