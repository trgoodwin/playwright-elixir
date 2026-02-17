defmodule Playwright.Page.FrameLocator do
  @moduledoc false

  alias Playwright.Locator
  alias Playwright.Page.FrameLocator

  @enforce_keys [:frame, :frame_selector]
  defstruct [:frame, :frame_selector]

  @type t() :: %__MODULE__{
          frame: Playwright.Frame.t(),
          frame_selector: binary()
        }

  @spec new(Playwright.Frame.t(), binary()) :: t()
  def new(frame, selector) do
    %FrameLocator{frame: frame, frame_selector: selector}
  end

  @spec locator(t(), binary()) :: Locator.t()
  def locator(%FrameLocator{} = fl, selector) do
    Locator.new(fl.frame, "#{fl.frame_selector} >> internal:control=enter-frame >> #{selector}")
  end

  @spec frame_locator(t(), binary()) :: t()
  def frame_locator(%FrameLocator{} = fl, selector) do
    %FrameLocator{
      frame: fl.frame,
      frame_selector: "#{fl.frame_selector} >> internal:control=enter-frame >> #{selector}"
    }
  end

  @spec owner(t()) :: Locator.t()
  def owner(%FrameLocator{} = fl) do
    Locator.new(fl.frame, fl.frame_selector)
  end

  @spec first(t()) :: t()
  def first(%FrameLocator{} = fl) do
    %FrameLocator{fl | frame_selector: "#{fl.frame_selector} >> nth=0"}
  end

  @spec last(t()) :: t()
  def last(%FrameLocator{} = fl) do
    %FrameLocator{fl | frame_selector: "#{fl.frame_selector} >> nth=-1"}
  end

  @spec nth(t(), integer()) :: t()
  def nth(%FrameLocator{} = fl, index) do
    %FrameLocator{fl | frame_selector: "#{fl.frame_selector} >> nth=#{index}"}
  end

  # get_by_* methods -- each delegates to locator/2 with the appropriate selector

  @spec get_by_alt_text(t(), binary(), map()) :: Locator.t()
  def get_by_alt_text(%FrameLocator{} = fl, text, options \\ %{}) do
    locator(fl, Locator.get_by_alt_text_selector(text, options))
  end

  @spec get_by_label(t(), binary(), map()) :: Locator.t()
  def get_by_label(%FrameLocator{} = fl, text, options \\ %{}) do
    locator(fl, Locator.get_by_label_selector(text, options))
  end

  @spec get_by_placeholder(t(), binary(), map()) :: Locator.t()
  def get_by_placeholder(%FrameLocator{} = fl, text, options \\ %{}) do
    locator(fl, Locator.get_by_placeholder_selector(text, options))
  end

  @spec get_by_role(t(), atom() | binary(), map()) :: Locator.t()
  def get_by_role(%FrameLocator{} = fl, role, options \\ %{}) do
    locator(fl, Locator.get_by_role_selector(role, options))
  end

  @spec get_by_test_id(t(), binary()) :: Locator.t()
  def get_by_test_id(%FrameLocator{} = fl, test_id) do
    locator(fl, Locator.get_by_test_id_selector(test_id))
  end

  @spec get_by_text(t(), binary(), map()) :: Locator.t()
  def get_by_text(%FrameLocator{} = fl, text, options \\ %{}) do
    locator(fl, Locator.get_by_text_selector(text, options))
  end

  @spec get_by_title(t(), binary(), map()) :: Locator.t()
  def get_by_title(%FrameLocator{} = fl, text, options \\ %{}) do
    locator(fl, Locator.get_by_title_selector(text, options))
  end
end
