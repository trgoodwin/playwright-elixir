defmodule Playwright.Video do
  @moduledoc false

  alias Playwright.Artifact

  @enforce_keys [:artifact]
  defstruct [:artifact]

  @type t :: %__MODULE__{
          artifact: Artifact.t()
        }

  @doc false
  def from_event(%{artifact: artifact}) do
    %__MODULE__{artifact: artifact}
  end

  @spec delete(t()) :: :ok
  def delete(%__MODULE__{artifact: artifact}) do
    Artifact.delete(artifact)
    :ok
  end

  @spec path(t()) :: binary()
  def path(%__MODULE__{artifact: artifact}) do
    artifact.path
  end

  @spec save_as(t(), binary()) :: :ok
  def save_as(%__MODULE__{artifact: artifact}, path) do
    Artifact.save_as(artifact, path)
    :ok
  end
end
