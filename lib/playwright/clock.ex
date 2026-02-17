defmodule Playwright.Clock do
  @moduledoc """
  `Playwright.Clock` provides methods to control the browser's clock.

  Clock allows you to fake time-related APIs such as `Date`, `setTimeout`,
  `setInterval`, and `requestAnimationFrame` in the browser.

  The Clock API is accessed through `Playwright.BrowserContext`. All methods
  accept a `BrowserContext` as their first argument.

  ## Example

      context = Browser.new_context(browser)
      Clock.install(context, %{time: "2024-01-01T00:00:00Z"})
      Clock.set_fixed_time(context, "2024-06-01T12:00:00Z")

  """

  alias Playwright.BrowserContext
  alias Playwright.SDK.Channel

  @type time :: number() | binary()
  @type ticks :: number() | binary()
  @type options :: map()

  @doc """
  Advance the clock by jumping forward in time. Only fires due timers at most once.

  ## Arguments

    - `context`: a `BrowserContext`
    - `ticks`: time to advance the clock by, in milliseconds (number) or a human-readable
      string (e.g. `"30:00"` for 30 minutes)
  """
  @spec fast_forward(BrowserContext.t(), ticks()) :: :ok
  def fast_forward(%BrowserContext{session: session, guid: guid}, ticks) do
    Channel.post(session, {:guid, guid}, :clock_fast_forward, parse_ticks(ticks))
    :ok
  end

  @doc """
  Install fake implementations for time-related functions including `Date`,
  `setTimeout`, `clearTimeout`, `setInterval`, `clearInterval`,
  `requestAnimationFrame`, and `cancelAnimationFrame`.

  ## Arguments

    - `context`: a `BrowserContext`
    - `options`: optional map that may contain:
      - `:time` — initial time to set, as a number (milliseconds since epoch) or ISO 8601 string
  """
  @spec install(BrowserContext.t(), options()) :: :ok
  def install(%BrowserContext{session: session, guid: guid}, options \\ %{}) do
    params =
      case Map.get(options, :time) do
        nil -> %{}
        time -> parse_time(time)
      end

    Channel.post(session, {:guid, guid}, :clock_install, params)
    :ok
  end

  @doc """
  Advance the clock by jumping forward in time and pause it. Once paused,
  no timers fire automatically.

  ## Arguments

    - `context`: a `BrowserContext`
    - `time`: time to pause at, as a number (milliseconds since epoch) or ISO 8601 string
  """
  @spec pause_at(BrowserContext.t(), time()) :: :ok
  def pause_at(%BrowserContext{session: session, guid: guid}, time) do
    Channel.post(session, {:guid, guid}, :clock_pause_at, parse_time(time))
    :ok
  end

  @doc """
  Resume timers. Previously paused timers will fire once the clock is resumed.

  ## Arguments

    - `context`: a `BrowserContext`
  """
  @spec resume(BrowserContext.t()) :: :ok
  def resume(%BrowserContext{session: session, guid: guid}) do
    Channel.post(session, {:guid, guid}, :clock_resume)
    :ok
  end

  @doc """
  Advance the clock, firing all timers along the way.

  ## Arguments

    - `context`: a `BrowserContext`
    - `ticks`: time to advance the clock by, in milliseconds (number) or a human-readable
      string (e.g. `"30:00"` for 30 minutes)
  """
  @spec run_for(BrowserContext.t(), ticks()) :: :ok
  def run_for(%BrowserContext{session: session, guid: guid}, ticks) do
    Channel.post(session, {:guid, guid}, :clock_run_for, parse_ticks(ticks))
    :ok
  end

  @doc """
  Make `Date.now` and `new Date()` always return a fixed fake time,
  without advancing the clock.

  ## Arguments

    - `context`: a `BrowserContext`
    - `time`: fixed time to set, as a number (milliseconds since epoch) or ISO 8601 string
  """
  @spec set_fixed_time(BrowserContext.t(), time()) :: :ok
  def set_fixed_time(%BrowserContext{session: session, guid: guid}, time) do
    Channel.post(session, {:guid, guid}, :clock_set_fixed_time, parse_time(time))
    :ok
  end

  @doc """
  Set the system time, but does not trigger any timers.

  ## Arguments

    - `context`: a `BrowserContext`
    - `time`: system time to set, as a number (milliseconds since epoch) or ISO 8601 string
  """
  @spec set_system_time(BrowserContext.t(), time()) :: :ok
  def set_system_time(%BrowserContext{session: session, guid: guid}, time) do
    Channel.post(session, {:guid, guid}, :clock_set_system_time, parse_time(time))
    :ok
  end

  # Private helpers
  # ---------------------------------------------------------------------------

  defp parse_ticks(ticks) when is_number(ticks), do: %{ticks_number: ticks}
  defp parse_ticks(ticks) when is_binary(ticks), do: %{ticks_string: ticks}

  defp parse_time(time) when is_number(time), do: %{time_number: time}
  defp parse_time(time) when is_binary(time), do: %{time_string: time}
end
