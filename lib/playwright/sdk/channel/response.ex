defmodule Playwright.SDK.Channel.Response do
  @moduledoc false
  alias Playwright.SDK.{Channel, ChannelOwner}

  defstruct [:message, :parsed]

  # API
  # ---------------------------------------------------------------------------

  def recv(session, message)

  def recv(session, %{guid: guid, method: "__create__", params: %{guid: _} = params}) when is_binary(guid) do
    catalog = Channel.Session.catalog(session)
    parent = (guid == "" && "Root") || guid

    {:ok, owner} = ChannelOwner.from(params, Channel.Catalog.get(catalog, parent))
    Channel.Catalog.put(catalog, owner)
  end

  def recv(session, %{guid: guid, method: "__dispose__"}) when is_binary(guid) do
    catalog = Channel.Session.catalog(session)
    Channel.Catalog.rm_r(catalog, guid)
  end

  def recv(session, %{guid: guid, method: method, params: params}) when is_binary(guid) do
    catalog = Channel.Session.catalog(session)
    owner = Channel.Catalog.get(catalog, guid)
    event = Channel.Event.new(owner, method, params, catalog)
    resolve(session, catalog, owner, event)
  end

  def recv(session, %{guid: guid, method: method}) when is_binary(guid) do
    recv(session, %{guid: guid, method: method, params: nil})
  end

  def recv(_session, %{result: %{playwright: _}}) do
    # Logger.info("Announcing Playwright!")
  end

  def recv(_session, %{error: error, id: _}) do
    Channel.Error.new(error, nil)
  end

  def recv(session, %{id: _} = message) do
    catalog = Channel.Session.catalog(session)
    build(message, catalog)
  end

  # private
  # ---------------------------------------------------------------------------

  defp build(message, catalog) do
    %__MODULE__{
      message: message,
      parsed: parse(message, catalog)
    }
  end

  defp parse(%{id: _id, result: result} = _message, catalog) do
    parse(Map.to_list(result), catalog)
  end

  defp parse(%{id: _id} = message, _catalog) do
    message
  end

  defp parse([{_key, %{guid: guid}}], catalog) do
    Channel.Catalog.get(catalog, guid)
  end

  # e.g., [rootAXNode: %{children: [%{name: "Hello World", role: "text"}], name: "", role: "WebArea"}],
  defp parse([{_key, %{} = result}], _catalog) do
    result
  end

  defp parse([browser: %{guid: browser_guid}, defaultContext: %{guid: context_guid}], catalog) do
    browser = Channel.Catalog.get(catalog, browser_guid)
    browser_context = Channel.Catalog.get(catalog, context_guid)
    if browser_context, do: Channel.patch(browser_context.session, {:guid, browser_context.guid}, %{browser: browser})
    browser
  end

  defp parse([{:binary, value}], _catalog) do
    value
  end

  defp parse([{:cookies, cookies}], _catalog) do
    cookies
  end

  defp parse([{:cookies, cookies}, {:origins, origins}], _catalog) do
    %{cookies: cookies, origins: origins}
  end

  defp parse([{:headers, headers}], _catalog) do
    headers
  end

  defp parse([{:elements, value}], catalog) do
    Enum.map(value, fn %{guid: guid} -> Channel.Catalog.get(catalog, guid) end)
  end

  defp parse([{:artifact, %{guid: guid}}, {:entries, _entries}], catalog) do
    Channel.Catalog.get(catalog, guid)
  end

  defp parse([{:entries, _entries}, {:artifact, %{guid: guid}}], catalog) do
    Channel.Catalog.get(catalog, guid)
  end

  defp parse([{:entries, entries}], _catalog) do
    entries
  end

  defp parse([{:value, value}], _catalog) do
    value
  end

  defp parse([{:values, values}], _catalog) do
    values
  end

  defp parse([{_key, nil}], _catalog) do
    nil
  end

  defp parse([{_key, value}], _catalog) do
    value
  end

  defp parse([], _catalog) do
    nil
  end

  defp resolve(session, catalog, owner, event) do
    bindings = Map.get(Channel.Session.bindings(session), {owner.guid, event.type}, [])

    resolved =
      Enum.reduce(bindings, event, fn callback, acc ->
        case callback.(acc) do
          {:patch, owner} ->
            Map.put(acc, :target, owner)

          _ok ->
            acc
        end
      end)

    Channel.Catalog.put(catalog, resolved.target)

    async_bindings = Map.get(Channel.Session.async_bindings(session), {owner.guid, event.type}, [])

    if async_bindings != [] do
      task_supervisor = Channel.Session.task_supervisor(session)

      Enum.each(async_bindings, fn callback ->
        Task.Supervisor.start_child(task_supervisor, fn -> callback.(resolved) end)
      end)
    end

    resolved
  end
end
