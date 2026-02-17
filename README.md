# Playwright for Elixir

**NOTE:** This package tracks Playwright v1.58.x. While not yet at full parity with the official Playwright API, significant coverage has been achieved across Page, Frame, Locator, Browser, BrowserContext, Request, Response, Route, ElementHandle, JSHandle, Worker, Mouse, Keyboard, Touchscreen, Download, FileChooser, Video, WebSocket, Tracing, Selectors, Coverage, Clock, and more.

## Overview

[Playwright](https://github.com/trgoodwin/playwright-elixir) is an Elixir library to automate Chromium, Firefox and WebKit with a single API. Playwright is built to enable cross-browser web automation that is **ever-green**, **capable**, **reliable** and **fast**. [See how Playwright is better](https://playwright.dev/docs/why-playwright).

## Installation

The package can be installed by adding `playwright` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:playwright, "~> 1.58.2-alpha.1"}
  ]
end
```

## Usage

- [README](https://hexdocs.pm/playwright/readme.html)
- [Getting started](https://hexdocs.pm/playwright/basics-getting-started.html)
- [API Reference](https://hexdocs.pm/playwright/api-reference.html)

## Example

```elixir
defmodule Test.ExampleTest do
  use ExUnit.Case, async: true
  use PlaywrightTest.Case

  describe "Navigating to playwright.dev" do
    test "works", %{browser: browser} do
      page = Playwright.Browser.new_page(browser)

      Playwright.Page.goto(page, "https://playwright.dev")
      text = Playwright.Page.text_content(page, ".navbar__title")

      assert text == "Playwright"
      Playwright.Page.close(page)
    end
  end
end
```

## Releases

This project aims to track the release versioning found in [Playwright proper](https://github.com/microsoft/playwright).

## Contributing

### Getting started

1. Clone the repo
2. Run `bin/dev/doctor` and for each problem, either use the suggested remedies or fix it some other way
3. Run `bin/dev/test` to run the test suite make sure everything is working

### Day-to-day

- Get latest code: `bin/dev/update`
- Run tests: `bin/dev/test`
- Start server: `bin/dev/start`
- Run tests and push: `bin/dev/shipit`

### Releasing

1. Update the version in `mix.exs`
   a. Search for and update the version anywhere it appears in the repo, such as this README
2. `git tag -a v${version_number}` such that the tag look like `v1.44.0-alpha.3` or `v1.44.0`
3. `git push --tags`
4. `mix hex.publish`
