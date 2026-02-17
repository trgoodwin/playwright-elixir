# Playwright API Parity Design

## Goal

Reach feature parity with the official Microsoft Playwright API (v1.58.x) through incremental, trunk-driven commits — each a cohesive unit with implementation and test coverage.

## Current State

- **Library version:** 1.49.1-alpha.1
- **Latest Playwright:** v1.58.2
- **Fully implemented (13 modules):** Browser, BrowserContext, Page, Frame, Locator, ElementHandle, JSHandle, Route, CDPSession, Keyboard, Accessibility, BindingCall, Artifact
- **Partially implemented (5):** BrowserType (Chromium only), Response (body/ok/text), Request (properties only), APIRequestContext (POST only), ConsoleMessage (properties only)
- **Stubbed but empty (16):** Dialog, Worker, Mouse, Touchscreen, Video, Download, FileChooser, FrameLocator, Coverage, Tracing, Selectors, WebSocket (methods), Android, Electron, APIRequest, FetchRequest
- **Not yet stubbed (4):** BrowserServer, WebSocketRoute, Clock, WebError

## Approach

Bottom-up by dependency. Each numbered step is a single commit to `main`, self-contained with implementation + tests, passing CI before the next step begins.

## Established Upgrade Pattern

Version upgrades follow a documented process used from v1.31 through v1.49:

1. Update `priv/static/package.json` to the new Playwright version
2. Run `npm install` in `priv/static/` (full node_modules tree is vendored since v1.42)
3. Run `mix playwright.install` to download new browser binaries
4. Run `mix test` — fix breakage or `@tag :skip` broken tests
5. Update version in `mix.exs` and README
6. Commit with message following the pattern: `check: v1.XX.0 - <result>`

## Phase 0: Foundation

### 0.0 — Inline `playwright_assets`

The test fixture server is currently a separate sibling repo (`../playwright-assets`) containing ~431 static files (~11MB) copied from Microsoft's `tests/assets/` plus a ~50-line Plug/Cowboy server.

- Copy `priv/assets/` and `priv/extras/` into `test/fixtures/assets/` and `test/fixtures/extras/`
- Move the Application + Router into `test/support/assets_server.ex`
- Add `{:plug_cowboy, "~> 2.1", only: :test}` and `{:plug, "~> 1.12", only: :test}` to deps
- Remove the `{:playwright_assets, path: "..."}` dependency
- Update `config/config.exs` to configure the in-repo asset server
- Add a `bin/dev/fetch-assets` script replicating the upstream fetch process (`git read-tree` from `microsoft/playwright`)
- Verify: `mix test` passes identically

### 0.1 — Upgrade to Playwright v1.58.x

Follow the established upgrade pattern:

1. `cd priv/static && npm install playwright@1.58.2`
2. `mix playwright.install`
3. `mix test` — fix or skip breakage
4. Update `mix.exs` version and README

### 0.2 — Firefox & WebKit support in BrowserType

- Remove the "not yet implemented" raises for Firefox/WebKit in `BrowserType.launch/2`
- The channel/driver already supports all three — the guards are artificial
- Add tests: launch Firefox, launch WebKit, basic navigation on each

## Phase 1: Modern Locator APIs

### 1.1 — `getBy*` methods on Frame

- `get_by_role/3`, `get_by_label/3`, `get_by_placeholder/3`, `get_by_alt_text/3`, `get_by_title/3`, `get_by_test_id/2`
- Pattern exists in `Frame.get_by_text/3` — follow it

### 1.2 — `getBy*` methods on Page and Locator

- Page delegates to Frame (established pattern)
- Locator composes with its own selector (established pattern in `Locator.get_by_text/3`)

### 1.3 — FrameLocator module

- Implement stubbed module: `frame_locator/2`, `locator/2`, `get_by_*/2-3`, `owner/1`
- Wire into `Page.frame_locator/2` and `Locator.frame_locator/2`

### 1.4 — Remaining Locator gaps

- `and_/2`, `filter/2`, `content_frame/1`, `press_sequentially/3`, `page/1`

## Phase 2: Dialog, ConsoleMessage, Worker

### 2.1 — Dialog

- `accept/2`, `dismiss/1`, `default_value/1`, `message/1`, `page/1`, `type/1`
- Wire `dialog` event on Page and BrowserContext

### 2.2 — ConsoleMessage

- `args/1`, `location/1`, `page/1`, `text/1`, `type/1`
- Wire `console` event on Page

### 2.3 — Worker

- `evaluate/3`, `evaluate_handle/3`, `url/1`
- Wire `worker` event on Page, `close` event on Worker

## Phase 3: Input Devices

### 3.1 — Mouse

- `click/4`, `dblclick/4`, `down/2`, `move/4`, `up/2`, `wheel/3`
- Wire `Page.mouse` property

### 3.2 — Touchscreen

- `tap/3`
- Wire `Page.touchscreen` property

## Phase 4: Request & Response Completion

### 4.1 — Request methods

- `all_headers/1`, `header_value/2`, `headers_array/1`, `response/1`, `sizes/1`

### 4.2 — Response methods

- `json/1`, `finished/1`, `all_headers/1`, `header_value/2`, `header_values/2`, `headers_array/1`, `security_details/1`, `server_addr/1`, `from_service_worker/1`

## Phase 5: Page Navigation & Lifecycle

### 5.1 — Navigation methods

- `go_back/2`, `go_forward/2`, `wait_for_url/3`

### 5.2 — Page lifecycle methods

- `bring_to_front/1`, `emulate_media/2`, `is_closed/1`, `opener/1`, `viewport_size/1`
- `add_script_tag/2`, `add_style_tag/2`, `pdf/2` (Chromium only)

### 5.3 — Page events

- Wire remaining events: `popup`, `crash`, `download`, `filechooser`, `websocket`, `worker`, `pageerror`, `domcontentloaded`, `load`, `frameattached`, `framedetached`, `framenavigated`

## Phase 6: Download, FileChooser, Video

### 6.1 — Download

- `cancel/1`, `delete/1`, `failure/1`, `page/1`, `path/1`, `save_as/2`, `suggested_filename/1`, `url/1`
- Likely wraps existing `Artifact` implementation
- Wire `download` event on Page

### 6.2 — FileChooser

- `element/1`, `is_multiple/1`, `page/1`, `set_files/3`
- Wire `filechooser` event on Page

### 6.3 — Video

- `delete/1`, `path/1`, `save_as/2`
- Accessed via `Page.video/1`

## Phase 7: Route Completion & WebSocket

### 7.1 — Route gaps

- `abort/2`, `fallback/2`, `fetch/2`

### 7.2 — WebSocket methods & events

- `is_closed/1`, `url/1`, `wait_for_event/3`
- Events: `close`, `framereceived`, `framesent`, `socketerror`

## Phase 8: BrowserContext Completion & APIRequestContext

### 8.1 — BrowserContext gaps

- `storage_state/2`, `set_default_timeout/2`, `set_default_navigation_timeout/2`
- `set_extra_http_headers/2`, `set_geolocation/2`
- `service_workers/1`, `unroute_all/2`, `wait_for_event/3`
- `route_from_har/3`, `route_web_socket/3`

### 8.2 — APIRequestContext

- `get/3`, `delete/3`, `patch/3`, `put/3`, `head/3`
- `fetch/3`, `dispose/1`, `storage_state/2`

## Phase 9: Tracing, Selectors, Coverage

### 9.1 — Tracing

- `start/2`, `stop/2`, `start_chunk/2`, `stop_chunk/2`, `group/3`, `group_end/1`

### 9.2 — Selectors

- `register/3`, `set_test_id_attribute/2`

### 9.3 — Coverage (Chromium only)

- `start_js_coverage/2`, `stop_js_coverage/1`, `start_css_coverage/2`, `stop_css_coverage/1`

## Phase 10: New Classes

### 10.1 — Clock

- `fast_forward/2`, `install/2`, `pause_at/2`, `resume/1`, `run_for/2`, `set_fixed_time/2`, `set_system_time/2`
- Access via `BrowserContext.clock` / `Page.clock`

### 10.2 — WebSocketRoute

- `close/2`, `connect_to_server/1`, `on_close/2`, `on_message/2`, `send/2`, `url/1`

### 10.3 — WebError

- `error/1`, `page/1`
- Wire `weberror` event on BrowserContext

### 10.4 — BrowserServer (low priority)

- `close/1`, `kill/1`, `process/1`, `ws_endpoint/1`
- For `launch_server` use case

## Out of Scope

- **Android / Electron** — niche platforms, defer indefinitely
- **Deprecated methods** — don't implement methods Playwright has deprecated (selector-based Page/Frame methods that duplicate Locator functionality)
- **Playwright Test runner features** — assertions, test runner, fixtures (these are test-framework-level, not API-level)
