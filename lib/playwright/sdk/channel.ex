defmodule Playwright.SDK.Channel do
  @moduledoc false
  import Playwright.SDK.Helpers.ErrorHandling
  alias Playwright.SDK.Channel.{Catalog, Connection, Error, Event, Message, Response, Session}

  # API
  # ---------------------------------------------------------------------------

  def bind(session, {:guid, guid}, event_type, callback) when is_binary(guid) do
    Session.bind(session, {guid, event_type}, callback)
  end

  def bind_async(session, {:guid, guid}, event_type, callback) when is_binary(guid) do
    Session.bind_async(session, {guid, event_type}, callback)
  end

  def find(session, {:guid, guid}, options \\ %{}) when is_binary(guid) do
    Session.catalog_table(session) |> Catalog.get(guid, options)
  end

  def list(session, {:guid, guid}, type) do
    Catalog.list(Session.catalog_table(session), %{
      parent: guid,
      type: type
    })
  end

  def patch(session, {:guid, guid}, data) when is_binary(guid) do
    table = Session.catalog_table(session)
    catalog = Session.catalog(session)
    owner = Catalog.get(table, guid)
    Catalog.put(table, catalog, Map.merge(owner, data))
  end

  def post(session, {:guid, guid}, action, params \\ %{}) when is_binary(guid) when is_pid(session) do
    connection = Session.connection(session)
    params = ensure_timeout(params)
    message = Message.new(guid, action, params)

    # IO.inspect(message, label: "---> Channel.post/4")

    with_timeout(params, fn timeout ->
      case Connection.post(connection, message, timeout) do
        {:ok, %{id: _} = result} ->
          {:ok, result}

        {:ok, resource} ->
          resource

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  def recv(session, {nil, message}) when is_map(message) do
    Response.recv(session, message)
    # |> IO.inspect(label: "<--- Channel.recv/2 A")
  end

  def recv(session, {from, message}) when is_map(message) do
    Response.recv(session, message)
    # |> IO.inspect(label: "<--- Channel.recv/2 B")
    |> reply(from, session)
  end

  # or, "expect"?
  def wait(session, owner, event_type, options \\ %{}, trigger \\ nil)

  def wait(session, {:guid, guid}, event_type, options, trigger) when is_map(options) do
    connection = Session.connection(session)

    with_timeout(options, fn timeout ->
      {:ok, event} = Connection.wait(connection, {:guid, guid}, event_type, timeout, trigger)
      evaluate(event, options)
    end)
  end

  def wait(session, {:guid, guid}, event, trigger, _) when is_function(trigger) do
    wait(session, {:guid, guid}, event, %{}, trigger)
  end

  # private
  # ---------------------------------------------------------------------------

  defp evaluate(%Event{} = event, options) do
    predicate = Map.get(options, :predicate)

    if predicate do
      with_timeout(options, fn timeout ->
        task =
          Task.async(fn ->
            evaluate(predicate, event.target, event)
          end)

        Task.await(task, timeout)
      end)
    else
      event
    end
  end

  defp evaluate(predicate, resource, event) do
    case predicate.(resource, event) do
      false ->
        # The predicate returned false. Since resource and event are immutable
        # values, retrying would never produce a different result. Block until
        # the enclosing Task.await timeout fires, which will produce the
        # expected {:error, timeout} via with_timeout.
        Process.sleep(:infinity)

      _ ->
        event
    end
  end

  # Playwright v1.58+ requires `timeout` as a mandatory float in all protocol
  # method params. Ensure it's always present with the default of 30_000ms.
  defp ensure_timeout(params) when is_map(params) do
    Map.put_new(params, :timeout, 30_000)
  end

  defp load_preview(items) when is_list(items) do
    Enum.map(items, &load_preview/1)
  end

  defp load_preview(%Playwright.ElementHandle{session: session} = handle) do
    case handle.preview do
      "JSHandle@node" ->
        catalog = Session.catalog(session)
        Catalog.watch(catalog, handle.guid, fn item -> item.preview != "JSHandle@node" end, %{timeout: 5_000})

      _hydrated ->
        handle
    end
  end

  defp load_preview(item) do
    item
  end

  defp reply(%Error{} = error, from, _session) do
    GenServer.reply(from, {:error, error})
  end

  defp reply(%Response{} = response, from, session) do
    task_supervisor = Session.task_supervisor(session)

    Task.Supervisor.start_child(task_supervisor, fn ->
      GenServer.reply(from, {:ok, load_preview(response.parsed)})
    end)
  end

  defp reply(%Event{} = event, from, _session) do
    GenServer.reply(from, {:ok, event})
  end
end
