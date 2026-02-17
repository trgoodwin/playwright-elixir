defmodule Playwright.Artifact do
  use Playwright.SDK.ChannelOwner

  alias Playwright.Artifact
  alias Playwright.SDK.ChannelOwner

  @property :path

  @impl ChannelOwner
  def init(message, initializer) do
    {:ok, %{message | path: initializer.absolute_path}}
  end

  def save_as(%Artifact{session: session, guid: guid}, path) do
    Channel.post(session, {:guid, guid}, :save_as, %{path: path})
  end

  def delete(%Artifact{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :delete)
  end

  def failure(%Artifact{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :failure)
  end

  def cancel(%Artifact{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :cancel)
    :ok
  end
end
