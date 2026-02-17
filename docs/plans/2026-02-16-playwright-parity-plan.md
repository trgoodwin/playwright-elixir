# Playwright API Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reach feature parity with the official Microsoft Playwright API (v1.58.x) through incremental trunk-driven commits.

**Architecture:** Each commit is a self-contained unit with implementation + tests on `main`. Bottom-up dependency ordering so each step builds on the last. The Elixir library wraps a vendored Node.js Playwright driver via a channel/transport RPC layer — all features flow through `Channel.post(session, {:guid, guid}, action, params)`.

**Tech Stack:** Elixir 1.18+, OTP 28, Node.js (vendored playwright-core), Plug/Cowboy (test server), ExUnit

---

## Task 0.0: Inline playwright_assets

Eliminate the sibling repo dependency by bringing the test fixture server and static files into this repo.

**Files:**
- Create: `test/support/assets_server.ex`
- Create: `test/fixtures/assets/` (copy from `../playwright-assets/priv/assets/`)
- Create: `test/fixtures/extras/` (copy from `../playwright-assets/priv/extras/`)
- Create: `bin/dev/fetch-assets`
- Modify: `mix.exs:47-62` (deps)
- Modify: `config/config.exs:12-17` (test config)
- Modify: `test/test_helper.exs`

**Step 1: Copy static fixtures into the repo**

```bash
cp -r ../playwright-assets/priv/assets test/fixtures/assets
cp -r ../playwright-assets/priv/extras test/fixtures/extras
```

Verify: `ls test/fixtures/assets/dom.html` exists.

**Step 2: Create the in-repo asset server**

Create `test/support/assets_server.ex`:

```elixir
defmodule Playwright.Test.AssetsServer do
  @moduledoc false
  use Plug.Router
  require Plug.Builder

  plug(:match)
  plug(:dispatch)

  get("/") do
    send_resp(conn, 200, "Serving Playwright assets")
  end

  match("/:root/:file") do
    respond_with(conn, "#{root}/#{file}")
  end

  match("/:root/:path/:file") do
    respond_with(conn, "#{root}/#{path}/#{file}")
  end

  match _ do
    send_resp(conn, 404, "404")
  end

  defp respond_with(conn, path) do
    fixtures_dir = Path.join([Application.app_dir(:playwright), "..", "..", "test", "fixtures"])

    case File.read(Path.join(fixtures_dir, path)) do
      {:error, :enoent} ->
        send_resp(conn, 404, "404")

      {:ok, body} ->
        conn = put_resp_header(conn, "x-playwright-request-method", conn.method)

        conn =
          if String.ends_with?(path, ".json"),
            do: put_resp_header(conn, "content-type", "application/json"),
            else: conn

        send_resp(conn, 200, body)
    end
  end
end
```

**Step 3: Update test_helper.exs to start the asset server**

Modify `test/test_helper.exs`:

```elixir
:erlang.system_flag(:backtrace_depth, 20)

# Start the test asset server
port = Application.get_env(:playwright, :test_assets_port, 4002)
{:ok, _} = Plug.Cowboy.http(Playwright.Test.AssetsServer, [], port: port, ip: {0, 0, 0, 0})

ExUnit.configure(exclude: [:headed, :ws])
ExUnit.start()
```

**Step 4: Update mix.exs dependencies**

In `mix.exs`, replace the `playwright_assets` dep and add plug_cowboy:

Replace:
```elixir
# {:playwright_assets, "1.49.1", only: [:test]},
{:playwright_assets, path: "../playwright-assets", only: [:test]},
```

With:
```elixir
{:plug_cowboy, "~> 2.7", only: [:test]},
{:plug, "~> 1.12", only: [:test]},
```

**Step 5: Update config/config.exs**

Replace:
```elixir
if config_env() == :test do
  config :logger, level: :info

  config :playwright_assets,
    port: 4002
end
```

With:
```elixir
if config_env() == :test do
  config :logger, level: :info

  config :playwright, :test_assets_port, 4002
end
```

**Step 6: Run tests to verify**

```bash
mix deps.get && mix test
```

Expected: All existing tests pass. The asset server starts on port 4002 and serves the same files.

**Step 7: Create the fetch-assets script**

Create `bin/dev/fetch-assets`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: bin/dev/fetch-assets <branch>
# Example: bin/dev/fetch-assets release-1.58

branch="${1:?Usage: bin/dev/fetch-assets <branch>}"
repo_root="$(git rev-parse --show-toplevel)"

echo "Fetching Playwright test assets from branch: ${branch}"

cd "${repo_root}"

if ! git remote | grep -q "playwright-upstream"; then
  git remote add --fetch --no-tags playwright-upstream https://github.com/microsoft/playwright.git
else
  git fetch playwright-upstream
fi

rm -rf test/fixtures/assets
git read-tree --prefix=test/fixtures/assets -u "playwright-upstream/${branch}:tests/assets"

# Remove oversized directories not needed for tests
rm -rf test/fixtures/assets/selenium-grid

echo "Assets updated from ${branch}"
```

```bash
chmod +x bin/dev/fetch-assets
```

**Step 8: Commit**

```bash
git add test/fixtures/ test/support/assets_server.ex test/test_helper.exs mix.exs config/config.exs bin/dev/fetch-assets
git commit -m "Inline playwright_assets into repo

Move the test fixture server and ~431 static asset files from the
separate playwright-assets repo into this repo. Eliminates the sibling
path dependency. Assets are served by a Plug router started in
test_helper.exs on port 4002."
```

---

## Task 0.1: Upgrade to Playwright v1.58.x

Follow the established upgrade pattern documented in git history.

**Files:**
- Modify: `priv/static/package.json`
- Modify: `priv/static/package-lock.json` (auto-generated)
- Modify: `priv/static/node_modules/` (auto-generated)
- Modify: `mix.exs:23` (version)
- Modify: `README.md` (version references)

**Step 1: Update the vendored Node.js package**

```bash
cd priv/static && npm install playwright@1.58.2
```

Expected: `package.json` shows `"playwright": "1.58.2"`, `node_modules/playwright-core/` updated.

**Step 2: Install new browser binaries**

```bash
cd ../.. && mix playwright.install
```

Expected: New Chromium, Firefox, and WebKit binaries downloaded.

**Step 3: Run test suite and assess**

```bash
mix test
```

Document failures. For each failure, either:
- Fix the Elixir code if the fix is small
- Add `@tag :skip` with a comment explaining why

**Step 4: Update version references**

In `mix.exs`, change:
```elixir
version: "1.49.1-alpha.1"
```
to:
```elixir
version: "1.58.2-alpha.1"
```

In `README.md`, update all version references from `1.49.1-alpha.1` to `1.58.2-alpha.1`.

**Step 5: Fetch updated test assets**

```bash
bin/dev/fetch-assets release-1.58
```

**Step 6: Run tests again**

```bash
mix test
```

Expected: All tests pass (or skipped tests are documented).

**Step 7: Commit**

```bash
git add -A
git commit -m "check: v1.58.2 - <result summary>"
```

---

## Task 0.2: Firefox & WebKit support in BrowserType

**Files:**
- Modify: `lib/playwright/browser_type.ex:92-104,158-178`
- Create: `test/api/browser_type/launch_test.exs`

**Step 1: Write failing tests for Firefox and WebKit launch**

Create `test/api/browser_type/launch_test.exs`:

```elixir
defmodule Playwright.BrowserType.LaunchTest do
  use Playwright.TestCase, async: true

  describe "BrowserType.launch/2" do
    test "launches Firefox", %{assets: assets} do
      {session, browser} = Playwright.BrowserType.launch(:firefox)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
      Playwright.Browser.close(browser)
    end

    test "launches WebKit", %{assets: assets} do
      {session, browser} = Playwright.BrowserType.launch(:webkit)
      page = Playwright.Browser.new_page(browser)
      response = Playwright.Page.goto(page, assets.empty)
      assert response
      Playwright.Browser.close(browser)
    end
  end
end
```

**Step 2: Run to verify they fail**

```bash
mix test test/api/browser_type/launch_test.exs -v
```

Expected: FAIL with `RuntimeError: not yet implemented`

**Step 3: Implement multi-browser support**

In `lib/playwright/browser_type.ex`, replace the chromium-only `launch` and the raise clause:

Replace lines 162-174:
```elixir
def launch(client, options)
    when is_atom(client) and client in [:chromium] do
  with {:ok, session} <- new_session(Transport.Driver, options),
       browser_type <- chromium(session),
       browser <- browser(browser_type, options) do
    {session, browser}
  end
end

def launch(client, _options)
    when is_atom(client) and client in [:firefox, :webkit] do
  raise RuntimeError, message: "not yet implemented: #{inspect(client)}"
end
```

With:
```elixir
def launch(client, options)
    when is_atom(client) and client in [:chromium, :firefox, :webkit] do
  with {:ok, session} <- new_session(Transport.Driver, options),
       browser_type <- browser_type_for(session, client),
       browser <- browser(browser_type, options) do
    {session, browser}
  end
end
```

Similarly for `connect_over_cdp`, replace lines 92-104:
```elixir
def connect_over_cdp(client, endpoint_url, options)
    when is_atom(client) and client in [:chromium] do
  with {:ok, session} <- new_session(Transport.Driver, options),
       browser_type <- chromium(session),
       cdp_browser <- _connect_over_cdp(browser_type, endpoint_url, options) do
    {session, cdp_browser}
  end
end

def connect_over_cdp(client, _endpoint_url, _options)
    when is_atom(client) and client in [:firefox, :webkit] do
  raise RuntimeError, message: "not yet implemented"
end
```

With:
```elixir
def connect_over_cdp(client, endpoint_url, options)
    when is_atom(client) and client in [:chromium] do
  with {:ok, session} <- new_session(Transport.Driver, options),
       browser_type <- browser_type_for(session, client),
       cdp_browser <- _connect_over_cdp(browser_type, endpoint_url, options) do
    {session, cdp_browser}
  end
end
```

Add the `browser_type_for` helper alongside the existing `chromium` helper:

```elixir
defp browser_type_for(session, client) when client in [:chromium, :firefox, :webkit] do
  playwright = playwright(session)
  %{guid: guid} = Map.get(playwright, client)
  Channel.find(session, {:guid, guid})
end
```

The existing `chromium/1` helper can be kept for backward compat or removed — it's only used internally.

**Step 4: Run tests**

```bash
mix test test/api/browser_type/launch_test.exs -v
```

Expected: PASS

**Step 5: Run full suite to verify no regressions**

```bash
mix test
```

Expected: All existing tests still pass.

**Step 6: Commit**

```bash
git add lib/playwright/browser_type.ex test/api/browser_type/launch_test.exs
git commit -m "Support Firefox and WebKit in BrowserType.launch/2

Replace chromium-only guards with a unified browser_type_for/2 helper
that resolves any browser type from the Playwright session. CDP remains
chromium-only as it's a Chrome-specific protocol."
```

---

## Task 1.1: getBy* methods on Frame

**Files:**
- Modify: `lib/playwright/frame.ex` (add `get_by_role`, `get_by_label`, `get_by_placeholder`, `get_by_alt_text`, `get_by_title`, `get_by_test_id`)
- Create: `test/api/frame/get_by_test.exs`

**Pattern to follow:** Look at the existing `Frame.get_by_text/3` implementation. Each `get_by_*` function constructs a selector string and returns `Locator.new(frame, selector)`. The selector format follows Playwright's internal selector engine syntax (e.g., `internal:role=button[name="Submit"s]`).

**Step 1:** Write tests for each `get_by_*` against test fixture pages (use `assets.prefix <> "/input/button.html"` or `assets.dom`).

**Step 2:** Implement each function following the `get_by_text` pattern.

**Step 3:** Run tests, verify, commit.

```bash
git commit -m "Add getBy* locator methods to Frame"
```

---

## Task 1.2: getBy* methods on Page and Locator

**Files:**
- Modify: `lib/playwright/page.ex` (delegate `get_by_*` to Frame, like existing `get_by_text`)
- Modify: `lib/playwright/locator.ex` (compose `get_by_*` with own selector, like existing `get_by_text`)
- Create: `test/api/page/get_by_test.exs`
- Modify: `test/api/locator_test.exs` (add get_by tests)

**Pattern:** Page delegates to `Frame.get_by_*` via main_frame. Locator composes by building a chained selector.

**Step 1:** Write tests. **Step 2:** Implement. **Step 3:** Commit.

```bash
git commit -m "Add getBy* methods to Page and Locator"
```

---

## Task 1.3: FrameLocator module

**Files:**
- Modify: `lib/playwright/page/frame_locator.ex` (implement stubbed module)
- Modify: `lib/playwright/page.ex` (add `frame_locator/2`)
- Modify: `lib/playwright/locator.ex` (add `frame_locator/2`)
- Create: `test/api/frame_locator_test.exs`

**Step 1:** Write tests using iframe fixtures. **Step 2:** Implement FrameLocator as a ChannelOwner with `locator/2`, `get_by_*/2-3`, `owner/1`. **Step 3:** Commit.

```bash
git commit -m "Implement FrameLocator module"
```

---

## Task 1.4: Remaining Locator gaps

**Files:**
- Modify: `lib/playwright/locator.ex` (add `and_/2`, `filter/2`, `content_frame/1`, `press_sequentially/3`, `page/1`)
- Modify: `test/api/locator_test.exs`

**Step 1:** Write tests. **Step 2:** Implement. **Step 3:** Commit.

```bash
git commit -m "Add Locator.and_, filter, content_frame, press_sequentially, page"
```

---

## Task 2.1: Dialog

**Files:**
- Modify: `lib/playwright/dialog.ex` (implement `accept/2`, `dismiss/1`, `default_value/1`, `message/1`, `page/1`, `type/1`)
- Modify: `lib/playwright/page.ex` (wire `dialog` event in `init/2`)
- Create: `test/api/dialog_test.exs`

**Step 1:** Write test: navigate to page with `window.alert()`, register `Page.on(page, :dialog, handler)`, verify dialog properties and accept/dismiss. **Step 2:** Implement Dialog methods via `Channel.post`. Wire the event in Page's `init/2` callback using `Channel.bind`. **Step 3:** Commit.

```bash
git commit -m "Implement Dialog with accept, dismiss, and event wiring"
```

---

## Task 2.2: ConsoleMessage

**Files:**
- Modify: `lib/playwright/console_message.ex` (add `args/1`, `location/1`, `page/1`, `text/1`, `type/1`)
- Create: `test/api/console_message_test.exs`

**Step 1:** Write test: `Page.on(page, :console, ...)`, evaluate `console.log("hello")`, verify message text and type. **Step 2:** Implement. **Step 3:** Commit.

```bash
git commit -m "Implement ConsoleMessage methods"
```

---

## Task 2.3: Worker

**Files:**
- Modify: `lib/playwright/worker.ex` (add `evaluate/3`, `evaluate_handle/3`, `url/1`)
- Modify: `lib/playwright/page.ex` (wire `worker` event)
- Create: `test/api/worker_test.exs`

**Step 1:** Write test using `assets.prefix <> "/worker/worker.html"` fixture. **Step 2:** Implement. **Step 3:** Commit.

```bash
git commit -m "Implement Worker with evaluate and event wiring"
```

---

## Task 3.1: Mouse

**Files:**
- Modify: `lib/playwright/mouse.ex` (implement `click/4`, `dblclick/4`, `down/2`, `move/4`, `up/2`, `wheel/3`)
- Modify: `lib/playwright/page.ex` (expose `mouse` property)
- Create: `test/api/page/mouse_test.exs`

**Step 1:** Write test: mouse click at coordinates on a button page. **Step 2:** Implement via `Channel.post` on the Page's guid with `"mouse.click"` etc. **Step 3:** Commit.

```bash
git commit -m "Implement Mouse input device"
```

---

## Task 3.2: Touchscreen

**Files:**
- Modify: `lib/playwright/touchscreen.ex` (implement `tap/3`)
- Modify: `lib/playwright/page.ex` (expose `touchscreen` property)
- Create: `test/api/page/touchscreen_test.exs`

**Step 1-3:** Same TDD pattern. Commit:

```bash
git commit -m "Implement Touchscreen.tap"
```

---

## Task 4.1: Request methods

**Files:**
- Modify: `lib/playwright/request.ex`
- Create: `test/api/request_test.exs` (expand existing `test/api/response_test.exs` patterns)

Add: `all_headers/1`, `header_value/2`, `headers_array/1`, `response/1`, `sizes/1`

```bash
git commit -m "Add Request methods: all_headers, header_value, response, sizes"
```

---

## Task 4.2: Response methods

**Files:**
- Modify: `lib/playwright/response.ex`
- Modify: `test/api/response_test.exs`

Add: `json/1`, `finished/1`, `all_headers/1`, `header_value/2`, `header_values/2`, `headers_array/1`, `security_details/1`, `server_addr/1`

```bash
git commit -m "Add Response methods: json, finished, all_headers, security_details, server_addr"
```

---

## Task 5.1: Navigation methods

**Files:**
- Modify: `lib/playwright/page.ex`
- Modify: `lib/playwright/frame.ex`
- Modify: `test/api/navigation_test.exs`

Add: `go_back/2`, `go_forward/2`, `wait_for_url/3`

```bash
git commit -m "Add Page.go_back, go_forward, wait_for_url"
```

---

## Task 5.2: Page lifecycle methods

**Files:**
- Modify: `lib/playwright/page.ex`
- Create: `test/api/page/lifecycle_test.exs`

Add: `bring_to_front/1`, `emulate_media/2`, `is_closed/1`, `opener/1`, `viewport_size/1`, `add_script_tag/2`, `add_style_tag/2`, `pdf/2`

```bash
git commit -m "Add Page lifecycle methods: bring_to_front, emulate_media, pdf, etc."
```

---

## Task 5.3: Page events

**Files:**
- Modify: `lib/playwright/page.ex` (init/2 event bindings)
- Modify: `test/api/page_test.exs`

Wire events: `popup`, `crash`, `download`, `filechooser`, `websocket`, `worker`, `pageerror`, `domcontentloaded`, `load`, `frameattached`, `framedetached`, `framenavigated`

```bash
git commit -m "Wire remaining Page events"
```

---

## Task 6.1: Download

**Files:**
- Modify: `lib/playwright/page/download.ex`
- Create: `test/api/download_test.exs`

Implement: `cancel/1`, `delete/1`, `failure/1`, `page/1`, `path/1`, `save_as/2`, `suggested_filename/1`, `url/1`. Wire `download` event on Page.

```bash
git commit -m "Implement Download module"
```

---

## Task 6.2: FileChooser

**Files:**
- Modify: `lib/playwright/file_chooser.ex`
- Create: `test/api/file_chooser_test.exs`

Implement: `element/1`, `is_multiple/1`, `page/1`, `set_files/3`. Wire `filechooser` event.

```bash
git commit -m "Implement FileChooser module"
```

---

## Task 6.3: Video

**Files:**
- Modify: `lib/playwright/page/video.ex`
- Create: `test/api/page/video_test.exs`

Implement: `delete/1`, `path/1`, `save_as/2`. Access via `Page.video/1`.

```bash
git commit -m "Implement Video module"
```

---

## Task 7.1: Route gaps

**Files:**
- Modify: `lib/playwright/route.ex`
- Modify: `test/api/page_test.exs` (route tests)

Add: `abort/2`, `fallback/2`, `fetch/2`

```bash
git commit -m "Add Route.abort, fallback, fetch"
```

---

## Task 7.2: WebSocket methods & events

**Files:**
- Modify: `lib/playwright/websocket.ex`
- Create: `test/api/websocket_test.exs`

Add methods and wire events: `close`, `framereceived`, `framesent`, `socketerror`.

```bash
git commit -m "Implement WebSocket methods and events"
```

---

## Task 8.1: BrowserContext gaps

**Files:**
- Modify: `lib/playwright/browser_context.ex`
- Modify: `test/api/browser_context_test.exs`

Add: `storage_state/2`, `set_default_timeout/2`, `set_default_navigation_timeout/2`, `set_extra_http_headers/2`, `set_geolocation/2`, `service_workers/1`, `unroute_all/2`, `wait_for_event/3`, `route_from_har/3`, `route_web_socket/3`

```bash
git commit -m "Complete BrowserContext API surface"
```

---

## Task 8.2: APIRequestContext

**Files:**
- Modify: `lib/playwright/api_request_context.ex`
- Create: `test/api/api_request_context_test.exs`

Add: `get/3`, `delete/3`, `patch/3`, `put/3`, `head/3`, `fetch/3`, `dispose/1`, `storage_state/2`

```bash
git commit -m "Complete APIRequestContext with all HTTP methods"
```

---

## Task 9.1: Tracing

**Files:**
- Modify: `lib/playwright/tracing.ex` or `lib/playwright/browser_context/tracing.ex`
- Create: `test/api/tracing_test.exs`

Implement: `start/2`, `stop/2`, `start_chunk/2`, `stop_chunk/2`, `group/3`, `group_end/1`

```bash
git commit -m "Implement Tracing"
```

---

## Task 9.2: Selectors

**Files:**
- Modify: `lib/playwright/selectors.ex`
- Create: `test/api/selectors_test.exs`

Implement: `register/3`, `set_test_id_attribute/2`

```bash
git commit -m "Implement Selectors.register and set_test_id_attribute"
```

---

## Task 9.3: Coverage

**Files:**
- Modify: `lib/playwright/coverage.ex`
- Create: `test/api/coverage_test.exs`

Implement (Chromium only): `start_js_coverage/2`, `stop_js_coverage/1`, `start_css_coverage/2`, `stop_css_coverage/1`

```bash
git commit -m "Implement Coverage (Chromium only)"
```

---

## Task 10.1: Clock

**Files:**
- Create: `lib/playwright/clock.ex`
- Modify: `lib/playwright/browser_context.ex` (add `clock` property)
- Create: `test/api/clock_test.exs`

Implement: `fast_forward/2`, `install/2`, `pause_at/2`, `resume/1`, `run_for/2`, `set_fixed_time/2`, `set_system_time/2`

```bash
git commit -m "Implement Clock"
```

---

## Task 10.2: WebSocketRoute

**Files:**
- Create: `lib/playwright/web_socket_route.ex`
- Create: `test/api/web_socket_route_test.exs`

Implement: `close/2`, `connect_to_server/1`, `on_close/2`, `on_message/2`, `send/2`, `url/1`

```bash
git commit -m "Implement WebSocketRoute"
```

---

## Task 10.3: WebError

**Files:**
- Create: `lib/playwright/web_error.ex`
- Modify: `lib/playwright/browser_context.ex` (wire `weberror` event)
- Create: `test/api/web_error_test.exs`

Implement: `error/1`, `page/1`

```bash
git commit -m "Implement WebError"
```

---

## Task 10.4: BrowserServer

**Files:**
- Create: `lib/playwright/browser_server.ex`
- Modify: `lib/playwright/browser_type.ex` (add `launch_server/2`)
- Create: `test/api/browser_server_test.exs`

Implement: `close/1`, `kill/1`, `process/1`, `ws_endpoint/1`

```bash
git commit -m "Implement BrowserServer"
```
