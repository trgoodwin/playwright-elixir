defmodule Playwright.Worker do
  @moduledoc false
  use Playwright.SDK.ChannelOwner
  alias Playwright.SDK.Helpers

  @property :url

  @type expression :: binary()

  # API
  # ---------------------------------------------------------------------------

  @doc """
  Returns the return value of `expression`.

  If the function passed to `evaluate/3` returns a non-serializable value,
  then `evaluate/3` resolves to `undefined`. Playwright also supports
  transferring some additional values that are not serializable by `JSON`:
  `-0`, `NaN`, `Infinity`, `-Infinity`.
  """
  @spec evaluate(t(), expression(), any()) :: any()
  def evaluate(owner, expression, arg \\ nil)

  def evaluate(%__MODULE__{session: session} = worker, expression, arg) do
    parse_result(fn ->
      Channel.post(session, {:guid, worker.guid}, :evaluate_expression, %{
        expression: expression,
        is_function: Helpers.Expression.function?(expression),
        arg: serialize(arg)
      })
    end)
  end

  @doc """
  Returns the return value of `expression` as a `Playwright.JSHandle`.

  The only difference between `evaluate/3` and `evaluate_handle/3` is that
  `evaluate_handle/3` returns a `Playwright.JSHandle`.
  """
  @spec evaluate_handle(t(), expression(), any()) :: term()
  def evaluate_handle(%__MODULE__{session: session} = worker, expression, arg \\ nil) do
    Channel.post(session, {:guid, worker.guid}, :evaluate_expression_handle, %{
      expression: expression,
      is_function: Helpers.Expression.function?(expression),
      arg: serialize(arg)
    })
  end

  @doc """
  Register a (non-blocking) callback/handler for various types of events.

  ## Supported events

  - `:close` — the Worker was terminated.

  ## Returns

  - `:ok`
  """
  @spec on(t(), atom(), function()) :: :ok
  def on(%__MODULE__{session: session, guid: guid}, event, callback) when is_atom(event) do
    Channel.bind(session, {:guid, guid}, event, callback)
    :ok
  end

  # private
  # ---------------------------------------------------------------------------

  defp parse_result(task) when is_function(task) do
    task.() |> Helpers.Serialization.deserialize()
  end

  defp serialize(arg) do
    Helpers.Serialization.serialize(arg)
  end
end
