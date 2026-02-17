defmodule Playwright.Selectors do
  @moduledoc """
  `Playwright.Selectors` can be used to install custom selector engines.

  Custom selector engines complement the built-in locators. Registration
  applies to the `Playwright.BrowserContext` through which the selectors
  are dispatched.

  ## Selector engine protocol

  In Playwright v1.49+, custom selector engines are registered per
  `BrowserContext` via the `registerSelectorEngine` action, and the test
  ID attribute is set via `setTestIdAttributeName`. This module provides
  convenience wrappers around those actions.

  ## Note

  `Selectors` is a client-side concept in recent Playwright versions.
  The `register/4` and `set_test_id_attribute/2` functions send commands
  to the `BrowserContext` dispatcher.
  """
  use Playwright.SDK.ChannelOwner

  @type options :: map()

  # API
  # ---------------------------------------------------------------------------

  @doc """
  Registers a custom selector engine.

  `script` may be a `binary()` containing the selector engine source code, or a
  `%{path: path}` map pointing to a JavaScript file that will be read.

  ## Returns

    - `:ok`

  ## Arguments

  | key/name  | type   |                              | description |
  | --------- | ------ | ---------------------------- | ----------- |
  | `context` | param  | `Playwright.BrowserContext.t()` | The browser context on which to register the engine. |
  | `name`    | param  | `binary()`                   | Name that is used in selectors as a prefix, e.g. `{name: "my-engine"}` enables `my-engine=...` selectors. |
  | `script`  | param  | `binary()` or `%{path: path}` | Script that evaluates to a selector engine instance. As a string: raw source; as a map with `:path`: path to a JS file. |
  | `options` | param  | `map()`                      | Optional. May include `content_script: true` to run in content script context. |
  """
  @spec register(Playwright.BrowserContext.t(), binary(), binary() | map(), options()) :: :ok
  def register(context, name, script, options \\ %{})

  def register(%Playwright.BrowserContext{session: session, guid: guid}, name, script, options) do
    source =
      case script do
        %{path: path} -> File.read!(path)
        source when is_binary(source) -> source
      end

    selector_engine = Map.merge(%{name: name, source: source}, options)
    params = %{selector_engine: selector_engine}
    Channel.post(session, {:guid, guid}, :register_selector_engine, params)
    :ok
  end

  @doc """
  Sets the attribute name to use for `get_by_test_id` locators. The default
  is `data-testid`.

  ## Returns

    - `:ok`

  ## Arguments

  | key/name         | type   |                              | description |
  | ---------------- | ------ | ---------------------------- | ----------- |
  | `context`        | param  | `Playwright.BrowserContext.t()` | The browser context on which to set the attribute. |
  | `attribute_name` | param  | `binary()`                   | The test ID attribute name. |
  """
  @spec set_test_id_attribute(Playwright.BrowserContext.t(), binary()) :: :ok
  def set_test_id_attribute(%Playwright.BrowserContext{session: session, guid: guid}, attribute_name) do
    Channel.post(session, {:guid, guid}, :set_test_id_attribute_name, %{test_id_attribute_name: attribute_name})
    :ok
  end
end
