defmodule Playwright.BrowserServer do
  @moduledoc false
  use Playwright.SDK.ChannelOwner

  @property :pid
  @property :ws_endpoint

  @spec close(t()) :: :ok
  def close(%__MODULE__{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :close)
    :ok
  end

  @spec kill(t()) :: :ok
  def kill(%__MODULE__{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :kill)
    :ok
  end
end
