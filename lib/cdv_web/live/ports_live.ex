defmodule CdvWeb.PortsLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "ports")
     |> assign(:filter, "")
     |> assign_async(:ports, fn ->
       case DumpServer.ports() do
         {:ok, list} -> {:ok, %{ports: list}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  @impl true
  def handle_event("filter", %{"value" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp visible(ports, ""), do: ports
  defp visible(ports, filter) do
    f = String.downcase(filter)
    Enum.filter(ports, fn p ->
      String.contains?(String.downcase(searchable(p.id)), f) or
      String.contains?(String.downcase(searchable(p.name)), f) or
      String.contains?(String.downcase(searchable(p.controls)), f) or
      String.contains?(String.downcase(searchable(p.connected)), f)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Ports</div>

    <.async_result :let={ports} assign={@ports}>
      <:loading><.loading label="Parsing ports from dump…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>
      <.port_table ports={ports} filter={@filter} />
    </.async_result>
    """
  end

  attr :ports, :list, required: true
  attr :filter, :string, required: true

  defp port_table(assigns) do
    assigns = assign(assigns, :filtered, visible(assigns.ports, assigns.filter))

    ~H"""
    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by ID, name, controls…"
             phx-keyup="filter" phx-debounce="150" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@ports) %> ports</span>
    </div>

    <table class="cdv-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Connected</th>
          <th>Controls</th>
          <th class="num">Input</th>
          <th class="num">Output</th>
          <th class="num">Queue</th>
        </tr>
      </thead>
      <tbody>
        <%= for p <- @filtered do %>
          <tr>
            <td class="mono">
              <.link navigate={~p"/port/#{port_encode(p.id)}"}>
                <%= fmt(p.id) %>
              </.link>
            </td>
            <td><%= fmt(p.name) %></td>
            <td class="mono" style="font-size:11px;"><%= fmt(p.connected) %></td>
            <td class="mono" style="font-size:11px; color:var(--text-dim);"><%= fmt(p.controls) %></td>
            <td class="num"><%= fmt(p.input) %></td>
            <td class="num"><%= fmt(p.output) %></td>
            <td class="num"><%= fmt(p.queue) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp fmt(nil), do: "—"
  defp fmt(v) when is_pid(v), do: v |> :erlang.pid_to_list() |> List.to_string()
  defp fmt({a, b}) when is_integer(a) and is_integer(b), do: "#{a}.#{b}"
  defp fmt(v) when is_tuple(v), do: inspect(v)
  defp fmt(v) when is_list(v) do
    try do
      if List.ascii_printable?(v), do: List.to_string(v), else: inspect(v)
    rescue
      _ -> inspect(v)
    end
  end
  defp fmt(v), do: to_string(v)

  defp port_encode(id), do: id |> fmt() |> URI.encode()
end
