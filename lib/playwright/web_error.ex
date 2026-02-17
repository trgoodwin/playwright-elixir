defmodule Playwright.WebError do
  @moduledoc false

  @enforce_keys [:error, :page]
  defstruct [:error, :page]

  @type t :: %__MODULE__{
          error: map(),
          page: Playwright.Page.t() | nil
        }

  @doc false
  def from_event(params) do
    %__MODULE__{
      error: params[:error] || params["error"],
      page: params[:page] || params["page"]
    }
  end

  @spec error(t()) :: map()
  def error(%__MODULE__{error: error}), do: error

  @spec page(t()) :: Playwright.Page.t() | nil
  def page(%__MODULE__{page: page}), do: page
end
