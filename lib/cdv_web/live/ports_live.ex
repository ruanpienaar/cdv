defmodule CdvWeb.PortsLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {ports, error} = fetch_ports()

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "ports")
     |> assign(:ports, ports)
     |> assign(:error, error)
     |> assign(:filter, "")}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp fetch_ports do
    case DumpServer.ports() do
      {:ok, list} -> {list, nil}
      {:error, e} -> {[], e}
    end
  end

  defp visible(ports, ""), do: ports
  defp visible(ports, filter) do
    f = String.downcase(filter)
    Enum.filter(ports, fn p ->
      String.contains?(String.downcase(to_string(p.id)), f) or
      String.contains?(String.downcase(to_string(p.name)), f) or
      String.contains?(String.downcase(to_string(p.controls)), f) or
      String.contains?(String.downcase(to_string(p.connected)), f)
    end)
  end

  @impl true
  def render(assigns) do
    filtered = visible(assigns.ports, assigns.filter)
    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="page-title">Ports</div>

    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by ID, name, controls…"
             phx-keyup="filter" phx-value-q="" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@ports) %> ports</span>
    </div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

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
