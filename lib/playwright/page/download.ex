defmodule Playwright.Download do
  @moduledoc false

  alias Playwright.Artifact

  @enforce_keys [:page, :url, :suggested_filename, :artifact]
  defstruct [:page, :url, :suggested_filename, :artifact]

  @type t :: %__MODULE__{
          page: Playwright.Page.t(),
          url: binary(),
          suggested_filename: binary(),
          artifact: Artifact.t()
        }

  @doc false
  def from_event(page, %{url: url, suggestedFilename: suggested_filename, artifact: artifact}) do
    %__MODULE__{
      page: page,
      url: url,
      suggested_filename: suggested_filename,
      artifact: artifact
    }
  end

  @spec cancel(t()) :: :ok
  def cancel(%__MODULE__{artifact: artifact}) do
    Artifact.cancel(artifact)
  end

  @spec delete(t()) :: :ok
  def delete(%__MODULE__{artifact: artifact}) do
    Artifact.delete(artifact)
    :ok
  end

  @spec failure(t()) :: binary() | nil
  def failure(%__MODULE__{artifact: artifact}) do
    Artifact.failure(artifact)
  end

  @spec page(t()) :: Playwright.Page.t()
  def page(%__MODULE__{page: page}), do: page

  @spec path(t()) :: binary()
  def path(%__MODULE__{artifact: artifact}) do
    artifact.path
  end

  @spec save_as(t(), binary()) :: :ok
  def save_as(%__MODULE__{artifact: artifact}, path) do
    Artifact.save_as(artifact, path)
    :ok
  end

  @spec suggested_filename(t()) :: binary()
  def suggested_filename(%__MODULE__{suggested_filename: name}), do: name

  @spec url(t()) :: binary()
  def url(%__MODULE__{url: url}), do: url
end
