defmodule Playwright.Page do
  @moduledoc """
  `Page` provides methods to interact with a single tab in a
  `Playwright.Browser`, or an [extension background page](https://developer.chrome.com/extensions/background_pages)
  in Chromium.

  One `Playwright.Browser` instance might have multiple `Page` instances.

  ## Example

  Create a page, navigate it to a URL, and save a screenshot:

      page = Browser.new_page(browser)
      resp = Page.goto(page, "https://example.com")

      Page.screenshot(page, %{path: "screenshot.png"})
      :ok = Page.close(page)

  The Page module is capable of handling various emitted events (described below).

  ## Example

  Log a message for a single page load event (WIP: `once` is not yet implemented):

      Page.once(page, :load, fn e ->
        IO.puts("page loaded!")
      end)

  Unsubscribe from events with the `remove_lstener` function (WIP: `remove_listener` is not yet implemented):

      def log_request(request) do
        IO.inspect(label: "A request was made")
      end

      Page.on(page, :request, fn e ->
        log_request(e.pages.request)
      end)

      Page.remove_listener(page, log_request)
  """
  use Playwright.SDK.ChannelOwner

  alias Playwright.SDK.Channel
  alias Playwright.{BrowserContext, ElementHandle, Frame, Page, Response}
  alias Playwright.SDK.{ChannelOwner, Helpers}

  @property :bindings
  @property :is_closed
  @property :main_frame
  @property :owned_context
  @property :routes

  # ---
  # @property :coverage
  # @property :keyboard
  # @property :mouse
  # @property :request
  # @property :touchscreen
  # ---

  # Override the auto-generated `is_closed/1` to handle the case where the page
  # has been disposed and removed from the catalog after closing.
  defoverridable is_closed: 1

  @spec is_closed(t()) :: boolean()
  def is_closed(%Page{is_closed: true}), do: true

  def is_closed(%Page{session: session, guid: guid}) do
    case Channel.find(session, {:guid, guid}, %{timeout: 10}) do
      %Page{is_closed: closed} -> closed == true
      _ -> true
    end
  end

  @type dimensions :: map()
  @type expression :: binary()
  @type function_or_options :: fun() | options() | nil
  @type options :: map()
  @type selector :: binary()
  @type serializable :: any()

  # callbacks
  # ---------------------------------------------------------------------------

  @impl ChannelOwner
  def init(%Page{session: session} = page, _intializer) do
    Channel.bind(session, {:guid, page.guid}, :close, fn event ->
      {:patch, %{event.target | is_closed: true}}
    end)

    Channel.bind(session, {:guid, page.guid}, :binding_call, fn %{params: %{binding: binding}, target: target} ->
      on_binding(target, binding)
    end)

    Channel.bind(session, {:guid, page.guid}, :route, fn %{target: target} = e ->
      on_route(target, e)
      # NOTE: will patch here
    end)

    {:ok, %{page | bindings: %{}, routes: []}}
  end

  # API
  # ---------------------------------------------------------------------------

  @doc """
  Adds a script to be evaluated before other scripts.

  The script is evaluated in the following scenarios:

  - Whenever the page is navigated.
  - Whenever a child frame is attached or navigated. In this case, the script
    is evaluated in the context of the newly attached frame.

  The script is evaluated after the document is created but before any of its
  scripts are run. This is useful to amend the JavaScript environment, e.g. to
  seed `Math.random`.

  ## Returns

    - `:ok`

  ## Arguments

  | key/name    | type   |                       | description |
  | ----------- | ------ | --------------------- | ----------- |
  | `script`    | param  | `binary()` or `map()` | As `binary()`: an inlined script to be evaluated; As `%{path: path}`: a path to a JavaScript file. |

  ## Example

  Overriding `Math.random` before the page loads:

      # preload.js
      Math.random = () => 42;

      Page.add_init_script(page, %{path: "preload.js"})

  ## Notes

  > While the official Node.js Playwright implementation supports an optional
  > `param: arg` for this function, the official Python implementation does
  > not. This implementation matches the Python for now.

  > The order of evaluation of multiple scripts installed via
  > `Playwright.BrowserContext.add_init_script/2` and
  > `Playwright.Page.add_init_script/2` is not defined.
  """
  @spec add_init_script(t(), binary() | map()) :: :ok
  def add_init_script(%Page{session: session} = page, script) when is_binary(script) do
    params = %{source: script}

    case Channel.post(session, {:guid, page.guid}, :add_init_script, params) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  def add_init_script(%Page{} = page, %{path: path} = script) when is_map(script) do
    add_init_script(page, File.read!(path))
  end

  # ---

  @doc """
  When testing a web page, sometimes unexpected overlays like a "Sign up"
  dialog appear and block actions you want to perform. These overlays don't
  always show up in the same way or at the same time, making them tricky to
  handle in automated tests.

  This method lets you set up a special function, called a handler, that
  activates when it detects that overlay is visible. The handler's job is to
  remove the overlay, allowing your test to continue as if the overlay wasn't
  there.

  ## Arguments

  | key/name   | type       |             | description |
  | ---------- | ---------- | ----------- | ----------- |
  | `locator`  | param      | `Locator.t()` | Locator that triggers the handler. |
  | `handler`  | param      | `function()` | Function that will be called when the locator appears. |
  | `options`  | param      | `map()`      | Options. `:no_wait_after` and `:times` are supported. |
  """
  @spec add_locator_handler(t(), Playwright.Locator.t(), function(), options()) :: :ok
  def add_locator_handler(%Page{session: session} = page, locator, handler, options \\ %{}) do
    no_wait_after = Map.get(options, :no_wait_after, false)

    params = %{selector: locator.selector, no_wait_after: no_wait_after}
    result = Channel.post(session, {:guid, page.guid}, "registerLocatorHandler", params)

    uid =
      case result do
        {:ok, %{id: _} = r} -> Map.get(r, :uid, Map.get(r, "uid"))
        %{uid: uid} -> uid
        other -> other
      end

    Channel.bind(session, {:guid, page.guid}, :locator_handler_triggered, fn %{params: event_params} = _event ->
      if Map.get(event_params, :uid) == uid do
        Task.start(fn ->
          try do
            handler.(locator)
          after
            Channel.post(session, {:guid, page.guid}, "resolveLocatorHandlerNoReply", %{uid: uid, remove: false})
          end
        end)
      end
    end)

    :ok
  end

  @doc """
  Removes a handler previously registered with `add_locator_handler/4`.
  """
  @spec remove_locator_handler(t(), Playwright.Locator.t()) :: :ok
  def remove_locator_handler(%Page{session: session} = page, locator) do
    Channel.post(session, {:guid, page.guid}, "unregisterLocatorHandler", %{selector: locator.selector})
    :ok
  end

  @spec add_script_tag(Page.t(), options()) :: ElementHandle.t()
  def add_script_tag(%Page{} = page, options \\ %{}) do
    main_frame(page) |> Frame.add_script_tag(options)
  end

  @spec add_style_tag(Page.t(), options()) :: ElementHandle.t()
  def add_style_tag(%Page{} = page, options \\ %{}) do
    main_frame(page) |> Frame.add_style_tag(options)
  end

  @spec bring_to_front(t()) :: :ok
  def bring_to_front(%Page{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :bring_to_front)
    :ok
  end

  # ---

  @spec click(t(), binary(), options()) :: :ok
  def click(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.click(selector, options)
  end

  @doc """
  Closes the `Page`.

  If the `Page` has an "owned context" (1-to-1 co-dependency with a
  `Playwright.BrowserContext`), that context is closed as well.

  If `option: run_before_unload` is false, does not run any unload handlers and
  waits for the page to be closed. If `option: run_before_unload` is `true`
  the function will run unload handlers, but will not wait for the page to
  close. By default, `Playwright.Page.close/1` does not run `:beforeunload`
  handlers.

  ## Returns

    - `:ok`

  ## Arguments

  | key/name            | type   |             | description |
  | ------------------- | ------ | ----------- | ----------- |
  | `run_before_unload` | option | `boolean()` | Whether to run the before unload page handlers. `(default: false)` |

  ## NOTE

  > if `option: run_before_unload` is passed as `true`, a `:beforeunload`
  > dialog might be summoned and should be handled manually via
  > `Playwright.Page.on/3`.
  """
  @spec close(t(), options()) :: :ok
  def close(%Page{session: session} = page, options \\ %{}) do
    # A call to `close` will remove the item from the catalog. `Catalog.find`
    # here ensures that we do not `post` a 2nd `close`.
    case Channel.find(session, {:guid, page.guid}, %{timeout: 10}) do
      %Page{} ->
        Channel.post(session, {:guid, page.guid}, :close, options)

        # NOTE: this *might* prefer to be done on `__dispose__`
        # ...OR, `.on(_, "close", _)`
        if page.owned_context do
          context(page) |> BrowserContext.close()
        end

        :ok

      {:error, _} ->
        :ok
    end
  end

  # ---

  # @spec content(Page.t()) :: binary()
  # def content(page)

  # ---

  # @doc """
  # Get the full HTML contents of the page, including the doctype.
  # """
  # @spec content(t()) :: binary()
  # def content(%Page{session: session} = page) do
  #   Channel.post(session, {:guid, page.guid}, :content)
  # end

  @doc """
  Get the `Playwright.BrowserContext` that the page belongs to.
  """
  @spec context(t()) :: BrowserContext.t()
  def context(page)

  def context(%Page{session: session} = page) do
    Channel.find(session, {:guid, page.parent.guid})
  end

  @spec content(t()) :: binary() | {:error, term()}
  def content(%Page{} = page) do
    main_frame(page) |> Frame.content()
  end

  @doc """
  A shortcut for the main frame's `Playwright.Frame.dblclick/3`.
  """
  @spec dblclick(t(), binary(), options()) :: :ok
  def dblclick(page, selector, options \\ %{})

  def dblclick(%Page{} = page, selector, options) do
    main_frame(page) |> Frame.dblclick(selector, options)
  end

  @doc """
  A shortcut for the main frame's `Playwright.Frame.dispatch_event/5`.
  """
  @spec dispatch_event(t(), binary(), atom() | binary(), Frame.evaluation_argument(), options()) :: :ok
  def dispatch_event(%Page{} = page, selector, type, event_init \\ nil, options \\ %{}) do
    main_frame(page) |> Frame.dispatch_event(selector, type, event_init, options)
  end

  @spec drag_and_drop(Page.t(), binary(), binary(), options()) :: Page.t()
  def drag_and_drop(page, source, target, options \\ %{}) do
    with_latest(page, fn page ->
      main_frame(page) |> Frame.drag_and_drop(source, target, options)
    end)
  end

  # ---

  @spec emulate_media(t(), options()) :: :ok
  def emulate_media(%Page{session: session, guid: guid}, options \\ %{}) do
    Channel.post(session, {:guid, guid}, :emulate_media, options)
    :ok
  end

  # ---

  @spec eval_on_selector(t(), binary(), binary(), term(), map()) :: term()
  def eval_on_selector(%Page{} = page, selector, expression, arg \\ nil, options \\ %{}) do
    main_frame(page)
    |> Frame.eval_on_selector(selector, expression, arg, options)
  end

  @spec evaluate(t(), expression(), any()) :: serializable()
  def evaluate(page, expression, arg \\ nil)

  def evaluate(%Page{} = page, expression, arg) do
    main_frame(page) |> Frame.evaluate(expression, arg)
  end

  @spec evaluate_handle(t(), expression(), any()) :: serializable()
  def evaluate_handle(%Page{} = page, expression, arg \\ nil) do
    main_frame(page) |> Frame.evaluate_handle(expression, arg)
  end

  # @spec expect_event(t(), atom() | binary(), function(), any(), any()) :: Playwright.SDK.Channel.Event.t()
  # def expect_event(page, event, trigger, predicate \\ nil, options \\ %{})

  # def expect_event(%Page{} = page, event, trigger, predicate, options) do
  #   context(page) |> BrowserContext.expect_event(event, trigger, predicate, options)
  # end

  def expect_event(page, event, options \\ %{}, trigger \\ nil)

  def expect_event(%Page{} = page, event, options, trigger)
      when event in [
             :request,
             "request",
             :response,
             "response",
             :request_finished,
             "requestFinished",
             :page,
             "page"
           ] do
    context(page) |> BrowserContext.expect_event(event, options, trigger)
  end

  def expect_event(%Page{session: session} = page, event, options, trigger) do
    Channel.wait(session, {:guid, page.guid}, event, options, trigger)
  end

  # ---

  # @spec expect_request(t(), binary() | function(), options()) :: :ok
  # def expect_request(page, url_or_predicate, options \\ %{})
  # ...defdelegate wait_for_request

  # @spec expect_response(t(), binary() | function(), options()) :: :ok
  # def expect_response(page, url_or_predicate, options \\ %{})
  # ...defdelegate wait_for_response

  @doc """
  Adds a function called `param:name` on the `window` object of every frame in
  this page.

  When called, the function executes `param:callback` and resolves to the return
  value of the `callback`.

  The first argument to the `callback` function includes the following details
  about the caller:

      %{
        context: %Playwright.BrowserContext{},
        frame:   %Playwright.Frame{},
        page:    %Playwright.Page{}
      }

  See `Playwright.BrowserContext.expose_binding/4` for a similar,
  context-scoped version.
  """
  @spec expose_binding(t(), binary(), function(), options()) :: Page.t()
  def expose_binding(%Page{session: session} = page, name, callback, options \\ %{}) do
    Channel.patch(session, {:guid, page.guid}, %{bindings: Map.merge(page.bindings, %{name => callback})})
    post!(page, :expose_binding, Map.merge(%{name: name, needs_handle: false}, options))
  end

  @doc """
  Adds a function called `param:name` on the `window` object of every frame in
  the page.

  When called, the function executes `param:callback` and resolves to the return
  value of the `callback`.

  See `Playwright.BrowserContext.expose_function/3` for a similar,
  context-scoped version.
  """
  @spec expose_function(Page.t(), String.t(), function()) :: Page.t()
  def expose_function(page, name, callback) do
    expose_binding(page, name, fn _, args ->
      callback.(args)
    end)
  end

  # ---

  @spec fill(t(), binary(), binary(), options()) :: :ok
  def fill(%Page{} = page, selector, value, options \\ %{}) do
    main_frame(page) |> Frame.fill(selector, value, options)
  end

  @doc """
  A shortcut for the main frame's `Playwright.Frame.focus/3`.
  """
  @spec focus(t(), binary(), options()) :: :ok
  def focus(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.focus(selector, options)
  end

  # ---

  @doc """
  Returns a frame matching the specified criteria (name or URL).

  ## Arguments

  | key/name | type   |            | description |
  | -------- | ------ | ---------- | ----------- |
  | `id`     | param  | `binary()` | Frame name or URL to match. |
  """
  @spec frame(t(), binary()) :: Frame.t() | nil
  def frame(%Page{} = page, id) when is_binary(id) do
    Enum.find(frames(page), fn f ->
      Frame.name(f) == id or Frame.url(f) == id
    end)
  end

  @spec frames(t()) :: [Frame.t()]
  def frames(%Page{} = page) do
    main = main_frame(page)
    children = Channel.list(page.session, {:guid, page.guid}, "Frame")
    if main, do: [main | children], else: children
  end

  # ---

  @spec frame_locator(Page.t(), binary()) :: Playwright.Page.FrameLocator.t()
  def frame_locator(page, selector) do
    main_frame(page) |> Frame.frame_locator(selector)
  end

  # ---

  @spec get_attribute(t(), binary(), binary(), map()) :: binary() | nil
  def get_attribute(%Page{} = page, selector, name, options \\ %{}) do
    main_frame(page) |> Frame.get_attribute(selector, name, options)
  end

  # ---

  @spec get_by_alt_text(Page.t(), binary(), options()) :: Playwright.Locator.t()
  def get_by_alt_text(page, text, options \\ %{}) do
    main_frame(page) |> Frame.get_by_alt_text(text, options)
  end

  @spec get_by_label(Page.t(), binary(), options()) :: Playwright.Locator.t()
  def get_by_label(page, text, options \\ %{}) do
    main_frame(page) |> Frame.get_by_label(text, options)
  end

  @spec get_by_placeholder(Page.t(), binary(), options()) :: Playwright.Locator.t()
  def get_by_placeholder(page, text, options \\ %{}) do
    main_frame(page) |> Frame.get_by_placeholder(text, options)
  end

  @spec get_by_role(Page.t(), atom() | binary(), options()) :: Playwright.Locator.t()
  def get_by_role(page, role, options \\ %{}) do
    main_frame(page) |> Frame.get_by_role(role, options)
  end

  @spec get_by_test_id(Page.t(), binary()) :: Playwright.Locator.t()
  def get_by_test_id(page, test_id) do
    main_frame(page) |> Frame.get_by_test_id(test_id)
  end

  @doc """
  Allows locating elements that contain given text.

  ## Arguments

  | key/name   | type   |            | description |
  | ---------- | ------ | ---------- | ----------- |
  | `text`     | param  | `binary()` | Text to locate the element for. |
  | `:exact`   | option | `boolean()`| Whether to find an exact match: case-sensitive and whole-string. Default to false. Ignored when locating by a regular expression. Note that exact match still trims whitespace. |
  """
  @spec get_by_text(Page.t(), binary(), %{optional(:exact) => boolean()}) :: Playwright.Locator.t() | nil
  def get_by_text(page, text, options \\ %{}) do
    main_frame(page) |> Frame.get_by_text(text, options)
  end

  @spec get_by_title(Page.t(), binary(), options()) :: Playwright.Locator.t()
  def get_by_title(page, text, options \\ %{}) do
    main_frame(page) |> Frame.get_by_title(text, options)
  end

  @doc """
  Navigate to the previous page in history.

  Returns the main resource response. In case of multiple redirects, the
  navigation will resolve with the response of the last redirect. If there is
  no previous page in history, returns `nil`.

  ## Returns

    - `Playwright.Response.t() | nil`

  ## Arguments

  | key/name      | type   |            | description |
  | ------------- | ------ | ---------- | ----------- |
  | `:timeout`    | option | `number()` | Maximum time in milliseconds. Pass `0` to disable timeout. `(default: 30 seconds)` |
  | `:wait_until` | option | `binary()` | "load", "domcontentloaded", "networkidle", or "commit". When to consider the operation as having succeeded. `(default: "load")` |
  """
  @spec go_back(t(), options()) :: Response.t() | nil
  def go_back(%Page{session: session} = page, options \\ %{}) do
    params = Map.merge(%{timeout: 30_000, wait_until: "load"}, options)

    case Channel.post(session, {:guid, page.guid}, :go_back, params) do
      %Response{} = response -> response
      _ -> nil
    end
  end

  @doc """
  Navigate to the next page in history.

  Returns the main resource response. In case of multiple redirects, the
  navigation will resolve with the response of the last redirect. If there is
  no next page in history, returns `nil`.

  ## Returns

    - `Playwright.Response.t() | nil`

  ## Arguments

  | key/name      | type   |            | description |
  | ------------- | ------ | ---------- | ----------- |
  | `:timeout`    | option | `number()` | Maximum time in milliseconds. Pass `0` to disable timeout. `(default: 30 seconds)` |
  | `:wait_until` | option | `binary()` | "load", "domcontentloaded", "networkidle", or "commit". When to consider the operation as having succeeded. `(default: "load")` |
  """
  @spec go_forward(t(), options()) :: Response.t() | nil
  def go_forward(%Page{session: session} = page, options \\ %{}) do
    params = Map.merge(%{timeout: 30_000, wait_until: "load"}, options)

    case Channel.post(session, {:guid, page.guid}, :go_forward, params) do
      %Response{} = response -> response
      _ -> nil
    end
  end

  # ---

  @spec goto(t(), binary(), options()) :: Response.t() | nil | {:error, term()}
  def goto(%Page{} = page, url, options \\ %{}) do
    main_frame(page) |> Frame.goto(url, options)
  end

  @doc """
  A shortcut for the main frame's `Playwright.Frame.hover/2`.
  """
  def hover(%Page{} = page, selector) do
    main_frame(page) |> Frame.hover(selector)
  end

  # ---

  # ---

  @spec locator(t(), selector()) :: Playwright.Locator.t()
  def locator(%Page{} = page, selector) do
    Playwright.Locator.new(page, selector)
  end

  # @spec main_frame(t()) :: Frame.t()
  # def main_frame(page)

  @spec opener(t()) :: t() | nil
  def opener(%Page{session: session, guid: guid}) do
    page = Channel.find(session, {:guid, guid})

    case page.initializer[:opener] do
      %{guid: opener_guid} -> Channel.find(session, {:guid, opener_guid})
      _ -> nil
    end
  end

  @doc """
  Pauses script execution. Playwright will stop executing the script and wait
  for the user to either press 'Resume' button in the page overlay or call
  `playwright.resume()` in the DevTools console.

  This is primarily useful in headed mode for debugging.
  """
  @spec pause(t()) :: :ok
  def pause(%Page{session: session} = page) do
    context = context(page)
    Channel.post(session, {:guid, context.guid}, :pause)
    :ok
  end

  # ---

  # on(...):
  #   - close
  #   - console
  #   - crash
  #   - dialog
  #   - domcontentloaded
  #   - download
  #   - filechooser
  #   - frameattached
  #   - framedetached
  #   - framenavigated
  #   - load
  #   - pageerror
  #   - popup
  #   - requestfailed
  #   - websocket
  #   - worker

  def on(%Page{} = page, event, callback) when is_binary(event) do
    on(page, String.to_atom(event), callback)
  end

  # NOTE: These events will be recv'd from Playwright server with the parent
  # BrowserContext as the context/bound :guid. So, we need to add our handlers
  # there, on that (BrowserContext) parent.
  #
  # For :update_subscription, :event is one of:
  # (console|dialog|fileChooser|request|response|requestFinished|requestFailed)
  def on(%Page{session: session} = page, event, callback)
      when event in [:console, :dialog, :request, :response, :request_finished, :request_failed] do
    # HACK!
    e = Atom.to_string(event) |> Recase.to_camel()

    Channel.post(session, {:guid, page.guid}, :update_subscription, %{event: e, enabled: true})
    Channel.bind_async(session, {:guid, context(page).guid}, event, callback)
  end

  # NOTE: The :file_chooser event is dispatched from the PageDispatcher (not
  # BrowserContext), so we bind to the Page's guid rather than the context's.
  def on(%Page{session: session} = page, :file_chooser, callback) do
    Channel.post(session, {:guid, page.guid}, :update_subscription, %{event: "fileChooser", enabled: true})
    Channel.bind_async(session, {:guid, page.guid}, :file_chooser, callback)
  end

  def on(%Page{session: session} = page, event, callback) when is_atom(event) do
    Channel.bind_async(session, {:guid, page.guid}, event, callback)
  end

  # ---

  @spec pdf(t(), options()) :: binary()
  def pdf(%Page{session: session, guid: guid}, options \\ %{}) do
    Channel.post(session, {:guid, guid}, :pdf, options)
    |> Base.decode64!()
  end

  # ---

  @spec press(t(), binary(), binary(), options()) :: :ok
  def press(%Page{} = page, selector, key, options \\ %{}) do
    main_frame(page) |> Frame.press(selector, key, options)
  end

  @spec query_selector(t(), selector(), options()) :: ElementHandle.t() | nil | {:error, :timeout}
  def query_selector(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.query_selector(selector, options)
  end

  defdelegate q(page, selector, options \\ %{}), to: __MODULE__, as: :query_selector

  @spec query_selector_all(t(), binary(), map()) :: [ElementHandle.t()]
  def query_selector_all(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.query_selector_all(selector, options)
  end

  defdelegate qq(page, selector, options \\ %{}), to: __MODULE__, as: :query_selector_all

  @doc """
  Reloads the current page.

  Reloads in the same way as if the user had triggered a browser refresh.

  Returns the main resource response. In case of multiple redirects, the
  navigation will resolve with the response of the last redirect.

  ## Returns

    - `Playwright.Response.t() | nil`

  ## Arguments

  | key/name      | type   |            | description |
  | ------------- | ------ | ---------- | ----------- |
  | `:timeout`    | option | `number()` | Maximum time in milliseconds. Pass `0` to disable timeout. The default value can be changed via `Playwright.BrowserContext.set_default_timeout/2` or `Playwright.Page.set_default_timeout/2`. `(default: 30 seconds)` |
  | `:wait_until` | option | `binary()` | "load", "domcontentloaded", "networkidle", or "commit". When to consider the operation as having succeeded. `(default: "load")` |

  ## On Wait Events

  - `domcontentloaded` - consider operation to be finished when the `DOMContentLoaded` event is fired.
  - `load` - consider operation to be finished when the `load` event is fired.
  - `networkidle` - consider operation to be finished when there are no network connections for at least `500 ms`.
  - `commit` - consider operation to be finished when network response is received and the document started loading.
  """
  @spec reload(t(), options()) :: Response.t() | nil
  def reload(%Page{session: session} = page, options \\ %{}) do
    Channel.post(session, {:guid, page.guid}, :reload, options)
  end

  # ---

  @spec request(t()) :: Playwright.APIRequestContext.t()
  def request(%Page{session: session} = page) do
    Channel.list(session, {:guid, page.owned_context.browser.guid}, "APIRequestContext")
    |> List.first()
  end

  @spec route(t(), binary(), function(), map()) :: :ok
  def route(page, pattern, handler, options \\ %{})

  def route(%Page{session: session} = page, pattern, handler, _options) do
    with_latest(page, fn page ->
      matcher = Helpers.URLMatcher.new(pattern)
      handler = Helpers.RouteHandler.new(matcher, handler)

      routes = [handler | page.routes]
      patterns = Helpers.RouteHandler.prepare(routes)

      Channel.patch(session, {:guid, page.guid}, %{routes: routes})
      Channel.post(session, {:guid, page.guid}, :set_network_interception_patterns, %{patterns: patterns})
    end)
  end

  # ---

  # @spec route_from_har(t(), binary(), map()) :: :ok
  # def route_from_har(page, har, options \\ %{})

  # ---

  @spec screenshot(t(), options()) :: binary()
  def screenshot(%Page{session: session} = page, options \\ %{}) do
    case Map.pop(options, :path) do
      {nil, params} ->
        Channel.post(session, {:guid, page.guid}, :screenshot, params)

      {path, params} ->
        [_, filetype] = String.split(path, ".")

        data = Channel.post(session, {:guid, page.guid}, :screenshot, Map.put(params, :type, filetype))
        File.write!(path, Base.decode64!(data))
        data
    end
  end

  @doc """
  A shortcut for the main frame's `Playwright.Frame.select_option/4`.
  """
  @spec select_option(t(), binary(), any(), options()) :: [binary()]
  def select_option(%Page{} = page, selector, values \\ nil, options \\ %{}) do
    main_frame(page) |> Frame.select_option(selector, values, options)
  end

  # ---

  # @spec set_checked(t(), binary(), boolean(), options()) :: :ok
  # def set_checked(page, selector, checked, options \\ %{})

  # ---

  @spec set_content(t(), binary(), options()) :: :ok
  def set_content(%Page{} = page, html, options \\ %{}) do
    main_frame(page) |> Frame.set_content(html, options)
  end

  @doc """
  Sets the default navigation timeout for the page.

  This is a client-only setting; no server-side dispatch is required.

  ## Returns

    - `:ok`
  """
  @spec set_default_navigation_timeout(t(), number()) :: :ok
  def set_default_navigation_timeout(%Page{} = _page, _timeout), do: :ok

  @doc """
  Sets the default timeout for all operations on the page.

  This is a client-only setting; no server-side dispatch is required.

  ## Returns

    - `:ok`
  """
  @spec set_default_timeout(t(), number()) :: :ok
  def set_default_timeout(%Page{} = _page, _timeout), do: :ok

  @doc """
  Sets extra HTTP headers that will be sent with every request the page initiates.

  These headers are merged with context-level extra HTTP headers set with
  `Playwright.BrowserContext.set_extra_http_headers/2`. If a page overrides a
  particular header, the page-specific header value will be used instead.

  ## Returns

    - `:ok`

  ## Arguments

  | key/name  | type   |              | description |
  | --------- | ------ | ------------ | ----------- |
  | `headers` | param  | `map()`      | A map of additional HTTP headers. All header values must be strings. |
  """
  @spec set_extra_http_headers(t(), map()) :: :ok
  def set_extra_http_headers(%Page{session: session, guid: guid}, headers) do
    headers_list = Enum.map(headers, fn {k, v} -> %{name: to_string(k), value: to_string(v)} end)
    Channel.post(session, {:guid, guid}, "setExtraHTTPHeaders", %{headers: headers_list})
    :ok
  end

  @doc """
  Requests the page to perform a garbage collection cycle.

  ## Returns

    - `:ok`
  """
  @spec request_gc(t()) :: :ok
  def request_gc(%Page{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, "requestGC")
    :ok
  end

  # ---

  @spec set_viewport_size(t(), dimensions()) :: :ok
  def set_viewport_size(%Page{session: session} = page, dimensions) do
    Channel.post(session, {:guid, page.guid}, :set_viewport_size, %{viewport_size: dimensions})
  end

  @spec text_content(t(), binary(), map()) :: binary() | nil
  def text_content(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.text_content(selector, options)
  end

  @spec title(t()) :: binary()
  def title(%Page{} = page) do
    main_frame(page) |> Frame.title()
  end

  # ---

  @doc """
  Removes a route created with `route/4`. When `handler` is not specified,
  removes all routes for the given `pattern`.
  """
  @spec unroute(t(), binary(), function() | nil) :: :ok
  def unroute(%Page{session: session} = page, pattern, callback \\ nil) do
    with_latest(page, fn page ->
      remaining =
        Enum.filter(page.routes, fn handler ->
          handler.matcher.match != pattern || (callback && handler.callback != callback)
        end)

      Channel.patch(session, {:guid, page.guid}, %{routes: remaining})

      patterns = Helpers.RouteHandler.prepare(remaining)
      Channel.post(session, {:guid, page.guid}, :set_network_interception_patterns, %{patterns: patterns})
    end)

    :ok
  end

  @doc """
  Removes all routes created with `route/4`.

  ## Returns

    - `:ok`
  """
  @spec unroute_all(t(), options()) :: :ok
  def unroute_all(%Page{session: session, guid: guid}, options \\ %{}) do
    _ = options
    Channel.patch(session, {:guid, guid}, %{routes: []})
    Channel.post(session, {:guid, guid}, :set_network_interception_patterns, %{patterns: []})
    :ok
  end

  # ---

  @spec url(t()) :: binary()
  def url(%Page{} = page) do
    main_frame(page) |> Frame.url()
  end

  # ---

  # @spec video(t()) :: Video.t() | nil
  # def video(page, handler \\ nil)

  @spec viewport_size(t()) :: dimensions() | nil
  def viewport_size(%Page{session: session, guid: guid}) do
    page = Channel.find(session, {:guid, guid})
    page.initializer[:viewport_size]
  end

  # @spec wait_for_event(t(), binary(), map()) :: map()
  # def wait_for_event(page, event, options \\ %{})

  # ---

  @spec wait_for_function(Page.t(), expression(), any(), options()) :: JSHandle.t()
  def wait_for_function(%Page{} = owner, expression, arg \\ nil, options \\ %{}) do
    main_frame(owner) |> Frame.wait_for_function(expression, arg, options)
  end

  @spec wait_for_load_state(t(), binary(), options()) :: Page.t()
  def wait_for_load_state(page, state \\ "load", options \\ %{})

  def wait_for_load_state(%Page{} = page, state, _options)
      when is_binary(state)
      when state in ["load", "domcontentloaded", "networkidle", "commit"] do
    main_frame(page) |> Frame.wait_for_load_state(state)
    page
  end

  def wait_for_load_state(%Page{} = page, state, options) when is_binary(state) do
    wait_for_load_state(page, state, options)
  end

  def wait_for_load_state(%Page{} = page, options, _) when is_map(options) do
    wait_for_load_state(page, "load", options)
  end

  @spec wait_for_selector(t(), binary(), map()) :: ElementHandle.t() | nil
  def wait_for_selector(%Page{} = page, selector, options \\ %{}) do
    main_frame(page) |> Frame.wait_for_selector(selector, options)
  end

  # ---

  @doc """
  Waits for the page to navigate to a URL matching the pattern.

  This is a shortcut for the main frame's `Playwright.Frame.wait_for_url/3`.

  ## Returns

    - `:ok`
    - `{:error, :timeout}`

  ## Arguments

  | key/name      | type   |            | description |
  | ------------- | ------ | ---------- | ----------- |
  | `url`         | param  | `binary()` | A URL string to match against. |
  | `:timeout`    | option | `number()` | Maximum time in milliseconds. Pass `0` to disable timeout. `(default: 30 seconds)` |
  | `:wait_until` | option | `binary()` | "load", "domcontentloaded", "networkidle", or "commit". When to consider the operation as having succeeded. `(default: "load")` |
  """
  @spec wait_for_url(t(), binary(), options()) :: :ok | {:error, :timeout}
  def wait_for_url(%Page{} = page, url, options \\ %{}) do
    main_frame(page) |> Frame.wait_for_url(url, options)
  end

  @doc """
  Returns all dedicated [WebWorkers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API)
  associated with the page.

  This does not contain ServiceWorkers.
  """
  @spec workers(t()) :: [Playwright.Worker.t()]
  def workers(%Page{session: session, guid: guid}) do
    Channel.list(session, {:guid, guid}, "Worker")
  end

  # ---

  # ... (like Locator?)
  # def accessibility(page)
  # def coverage(page)
  # def keyboard(page)
  # def mouse(page)
  # def request(page)
  # def touchscreen(page)

  # ---

  # private
  # ---------------------------------------------------------------------------

  defp on_binding(page, binding) do
    Playwright.BindingCall.call(binding, Map.get(page.bindings, binding.name))
  end

  # Do not love this.
  # It's good enough for now (to deal with v1.26.0 changes). However, it feels
  # dirty for API resource implementations to be reaching into Catalog.
  defp on_route(page, %{params: %{route: %{request: request} = route} = _params} = _event) do
    Enum.reduce_while(page.routes, [], fn handler, acc ->
      catalog = Channel.Session.catalog(page.session)
      request = Channel.Catalog.get(catalog, request.guid)

      if Helpers.RouteHandler.matches(handler, request.url) do
        Helpers.RouteHandler.handle(handler, %{request: request, route: route})
        # break
        {:halt, acc}
      else
        {:cont, [handler | acc]}
      end
    end)
  end
end
