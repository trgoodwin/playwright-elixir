# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elixir bindings for [Playwright](https://playwright.dev) browser automation. Currently in alpha, tracking Playwright JS version (1.49.1-alpha.1). Automates Chromium, Firefox, and WebKit.

## Common Commands

```bash
mix deps.get                    # Install dependencies
mix playwright.install          # Install browser binaries (required before tests)
mix test                        # Run all tests
mix test test/api/page_test.exs # Run a single test file
mix test test/api/page_test.exs:42  # Run a specific test by line
mix format                      # Format code (line_length: 130)
mix credo                       # Lint (max line: 120, run in test env)
mix dialyzer                    # Type checking
```

**Environment variables:**
- `PLAYWRIGHT_TRANSPORT` — `driver` (default) or `websocket`
- `PLAYWRIGHT_HEADLESS` — `true` (default) or `false`
- `PLAYWRIGHT_ENDPOINT` — WebSocket URL (default: `ws://localhost:3000/`)

**Test tags:** Tests tagged `:headed` or `:ws` are excluded by default (see `test/test_helper.exs`). Run them with `mix test --include headed` or `--include ws`.

## Architecture

### Three-Layer Design

**1. Public API** (`lib/playwright/*.ex`) — User-facing modules: `Playwright`, `Browser`, `BrowserContext`, `Page`, `Frame`, `Locator`, `ElementHandle`, `Request`, `Response`, `Route`, etc. All implement the `ChannelOwner` behavior.

**2. SDK Core** (`lib/playwright/sdk/`) — Internal communication layer:
- **Channel system** (`channel/`) — `Session` (GenServer managing lifecycle), `Catalog` (GenServer storing resource objects), `Connection` (bidirectional messaging), `Channel` (orchestrator with `post/4`, `find/2`, `bind/4`)
- **Transport** (`transport/`) — `Driver` (Node.js child process via stdio) or `WebSocket` (remote Playwright server via `gun`)
- **Helpers** (`helpers/`) — Serialization, URL matching, route handling, JS expression helpers
- **Extras** (`extra/`) — Snake/camelCase conversion utilities

**3. Test framework** (`lib/playwright_test/case.ex`) — `PlaywrightTest.Case` provides `use PlaywrightTest.Case` for ExUnit integration, auto-managing browser/page lifecycle in test context.

### ChannelOwner Pattern

All Playwright objects (Browser, Page, Frame, etc.) use `use Playwright.SDK.ChannelOwner`. This macro:
- Defines the struct with `@property` fields plus standard fields (`:session`, `:guid`, `:initializer`, `:listeners`, `:parent`, `:type`)
- Generates accessor functions for each `@property` that auto-refresh from the Catalog
- Provides `init/2` callback for post-creation setup (event binding, state patching)
- Provides `post!/3` for sending commands and `on_event/2` for handling events
- Auto-converts snake_case ↔ camelCase for initializer properties

### Message Flow

```
User Code → API module → Channel.post(session, guid, action, params)
  → Session → Transport (Driver or WebSocket)
  → Playwright Server → Response
  → Connection.recv() → Catalog update → Channel.find()
  → User Code
```

### OTP Supervision

`Playwright.Application` starts:
1. `Playwright.SDK.Channel.SessionID` — ID generator
2. `DynamicSupervisor` (`Session.Supervisor`) — manages parallel browser sessions

Each `Playwright.launch/2` or `Playwright.connect/2` call spawns a new Session under this supervisor.

### Test Infrastructure

- `Playwright.TestCase` (`test/support/test_case.ex`) — internal test case template extending `PlaywrightTest.Case`, adds `assert_next_receive/2`, `attach_frame/3`, and asset URL helpers (served on `localhost:4002`)
- `playwright_assets` dependency provides the test asset server
- Tests in `test/api/` cover API integration; `test/sdk/` covers SDK internals

## Key Conventions

- Properties on channel owner modules are declared with `@property :name` (custom macro, not the standard `@` operator)
- The `init/2` callback returns `{:ok, owner}` and is the place to bind event listeners via `Channel.bind/4`
- Event listeners can return `{:patch, updated_struct}` to update the object in the Catalog
- GUIDs identify all Playwright objects; lookups go through `Channel.find(session, {:guid, guid})`
