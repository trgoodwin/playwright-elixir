defmodule Playwright.FileChooser do
  @moduledoc false

  alias Playwright.ElementHandle

  @enforce_keys [:page, :element, :is_multiple]
  defstruct [:page, :element, :is_multiple]

  @type t :: %__MODULE__{
          page: Playwright.Page.t(),
          element: ElementHandle.t(),
          is_multiple: boolean()
        }

  @doc false
  def from_event(page, %{element: element} = params) do
    is_multiple = Map.get(params, :isMultiple, Map.get(params, :is_multiple, false))

    %__MODULE__{
      page: page,
      element: element,
      is_multiple: is_multiple
    }
  end

  @spec element(t()) :: ElementHandle.t()
  def element(%__MODULE__{element: element}), do: element

  @spec is_multiple(t()) :: boolean()
  def is_multiple(%__MODULE__{is_multiple: is_multiple}), do: is_multiple

  @spec page(t()) :: Playwright.Page.t()
  def page(%__MODULE__{page: page}), do: page

  @spec set_files(t(), binary() | [binary()], map()) :: :ok
  def set_files(%__MODULE__{element: element}, files, options \\ %{}) do
    ElementHandle.set_input_files(element, files, options)
  end
end
