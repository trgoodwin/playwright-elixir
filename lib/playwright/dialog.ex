defmodule Playwright.Dialog do
  @moduledoc false
  use Playwright.SDK.ChannelOwner
  alias Playwright.SDK.Channel

  @property :message
  @property :default_value

  @doc """
  Returns the type of the dialog.

  Can be one of `"alert"`, `"beforeunload"`, `"confirm"`, or `"prompt"`.
  """
  @spec type(t()) :: binary()
  def type(%__MODULE__{} = dialog) do
    dialog = Channel.find(dialog.session, {:guid, dialog.guid})
    dialog.type
  end

  @doc """
  Accepts the dialog.

  ## Arguments

  | key/name     | type       | description |
  | ------------ | ---------- | ----------- |
  | `prompt_text`| `binary()` | Text to enter in a prompt dialog. Has no effect for other dialog types. |
  """
  @spec accept(t(), binary()) :: :ok
  def accept(%__MODULE__{session: session, guid: guid}, prompt_text \\ "") do
    Channel.post(session, {:guid, guid}, :accept, %{prompt_text: prompt_text})
  end

  @doc """
  Dismisses the dialog.
  """
  @spec dismiss(t()) :: :ok
  def dismiss(%__MODULE__{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :dismiss, %{})
  end
end
