defmodule Playwright.Coverage do
  @moduledoc false

  alias Playwright.Page
  alias Playwright.SDK.Channel

  @type options :: map()

  @spec start_js_coverage(Page.t(), options()) :: :ok
  def start_js_coverage(%Page{} = page, options \\ %{}) do
    Channel.post(page.session, {:guid, page.guid}, "startJSCoverage", options)
    :ok
  end

  @spec stop_js_coverage(Page.t()) :: [map()]
  def stop_js_coverage(%Page{} = page) do
    Channel.post(page.session, {:guid, page.guid}, "stopJSCoverage")
  end

  @spec start_css_coverage(Page.t(), options()) :: :ok
  def start_css_coverage(%Page{} = page, options \\ %{}) do
    Channel.post(page.session, {:guid, page.guid}, "startCSSCoverage", options)
    :ok
  end

  @spec stop_css_coverage(Page.t()) :: [map()]
  def stop_css_coverage(%Page{} = page) do
    Channel.post(page.session, {:guid, page.guid}, "stopCSSCoverage")
  end
end
