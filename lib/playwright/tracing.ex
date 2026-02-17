defmodule Playwright.Tracing do
  @moduledoc """
  API for collecting and saving Playwright traces. Playwright traces can be
  opened in the [Trace Viewer](https://playwright.dev/docs/trace-viewer)
  after Playwright script runs.

  Tracing is accessed via `BrowserContext.tracing(context)`.

  ## Example

      context = Browser.new_context(browser)
      tracing = BrowserContext.tracing(context)

      Tracing.start(tracing, %{screenshots: true, snapshots: true})
      page = BrowserContext.new_page(context)
      Page.goto(page, "https://example.com")
      Tracing.stop(tracing, %{path: "trace.zip"})
  """
  use Playwright.SDK.ChannelOwner

  alias Playwright.{Artifact, BrowserContext}

  @type options :: map()

  @doc """
  Start tracing.

  ## Options

    - `:name` - If specified, intermediate trace files are saved into the
      files with the given name prefix inside the
      `traces_dir` directory specified in `BrowserType.launch/2`.
    - `:screenshots` - Whether to capture screenshots during tracing.
      Screenshots are used to build a timeline preview. Defaults to `false`.
    - `:snapshots` - If this option is `true`, tracing will capture DOM
      snapshots and record network activity. Defaults to `false`.
    - `:title` - Trace name to be shown in the Trace Viewer.
  """
  @spec start(BrowserContext.t() | t(), options()) :: :ok
  def start(owner, options \\ %{})

  def start(%BrowserContext{} = context, options) do
    context |> BrowserContext.tracing() |> start(options)
  end

  def start(%__MODULE__{session: session, guid: guid}, options) do
    start_params = Map.take(options, [:name, :screenshots, :snapshots])
    Channel.post(session, {:guid, guid}, :tracing_start, start_params)

    chunk_params = Map.take(options, [:name, :title])
    Channel.post(session, {:guid, guid}, :tracing_start_chunk, chunk_params)

    :ok
  end

  @doc """
  Start a new trace chunk. If you'd like to record multiple traces on the
  same `BrowserContext`, use `start/2` once, and then create multiple trace
  chunks with `start_chunk/2` and `stop_chunk/2`.

  ## Options

    - `:name` - If specified, intermediate trace files are saved into the
      files with the given name prefix inside the `traces_dir` directory.
    - `:title` - Trace name to be shown in the Trace Viewer.
  """
  @spec start_chunk(BrowserContext.t() | t(), options()) :: :ok
  def start_chunk(owner, options \\ %{})

  def start_chunk(%BrowserContext{} = context, options) do
    context |> BrowserContext.tracing() |> start_chunk(options)
  end

  def start_chunk(%__MODULE__{session: session, guid: guid}, options) do
    Channel.post(session, {:guid, guid}, :tracing_start_chunk, options)
    :ok
  end

  @doc """
  Stop tracing.

  ## Options

    - `:path` - Export trace into the file with the given path.
  """
  @spec stop(BrowserContext.t() | t(), options()) :: :ok
  def stop(owner, options \\ %{})

  def stop(%BrowserContext{} = context, options) do
    context |> BrowserContext.tracing() |> stop(options)
  end

  def stop(%__MODULE__{session: session, guid: guid} = tracing, options) do
    do_stop_chunk(tracing, Map.get(options, :path))
    Channel.post(session, {:guid, guid}, :tracing_stop)
    :ok
  end

  @doc """
  Stop the trace chunk. If you'd like to record multiple traces on the same
  `BrowserContext`, use `start/2` once, and then create multiple trace chunks
  with `start_chunk/2` and `stop_chunk/2`.

  ## Options

    - `:path` - Export trace collected since the last `start_chunk/2` call
      into the file with the given path.
  """
  @spec stop_chunk(BrowserContext.t() | t(), options()) :: :ok
  def stop_chunk(owner, options \\ %{})

  def stop_chunk(%BrowserContext{} = context, options) do
    context |> BrowserContext.tracing() |> stop_chunk(options)
  end

  def stop_chunk(%__MODULE__{} = tracing, options) do
    do_stop_chunk(tracing, Map.get(options, :path))
    :ok
  end

  # private
  # ---------------------------------------------------------------------------

  defp do_stop_chunk(%__MODULE__{session: session, guid: guid}, nil) do
    Channel.post(session, {:guid, guid}, :tracing_stop_chunk, %{mode: "discard"})
  end

  defp do_stop_chunk(%__MODULE__{session: session, guid: guid}, path) when is_binary(path) do
    result = Channel.post(session, {:guid, guid}, :tracing_stop_chunk, %{mode: "archive"})

    case result do
      %Artifact{} = artifact ->
        Artifact.save_as(artifact, path)
        Artifact.delete(artifact)

      _ ->
        :ok
    end
  end
end
