defmodule CdvWeb.NodesLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {nodes, error} = fetch_nodes()

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "nodes")
     |> assign(:nodes, nodes)
     |> assign(:error, error)
     |> assign(:selected, nil)}
  end

  @impl true
  def handle_event("select", %{"idx" => idx}, socket) do
    i = String.to_integer(idx)
    node = Enum.at(socket.assigns.nodes, i)
    selected = if socket.assigns.selected == i, do: nil, else: i
    {:noreply, socket |> assign(:selected, selected) |> assign(:selected_node, node)}
  end

  defp fetch_nodes do
    case DumpServer.nodes() do
      {:ok, list} -> {list, nil}
      {:error, e} -> {[], e}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Nodes</div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

    <%= if @nodes == [] do %>
      <div style="color:var(--muted); font-family:var(--font-mono);">No distributed nodes found.</div>
    <% else %>
      <table class="cdv-table">
        <thead>
          <tr>
            <th>Name</th>
            <th class="num">Channel</th>
            <th>Type</th>
            <th>Controller</th>
            <th>Creation</th>
            <th>Error</th>
          </tr>
        </thead>
        <tbody>
          <%= for {n, idx} <- Enum.with_index(@nodes) do %>
            <tr class={if @selected == idx, do: "row-selected", else: ""} phx-click="select" phx-value-idx={idx} style="cursor:pointer;">
              <td class="mono"><%= fmt(n.name) %></td>
              <td class="num"><%= fmt(n.channel) %></td>
              <td class="mono" style="font-size:11px;"><%= fmt(n.conn_type) %></td>
              <td class="mono" style="font-size:11px;"><%= fmt(n.controller) %></td>
              <td class="mono" style="font-size:11px;"><%= fmt(n.creation) %></td>
              <td style="color:var(--red); font-size:11px;"><%= fmt(n.error) %></td>
            </tr>
            <%= if @selected == idx do %>
              <tr>
                <td colspan="6" style="padding:0;">
                  <div class="card" style="margin:0.5rem 0;">
                    <%= if @selected_node.remote_links not in [nil, [], ""] do %>
                      <div class="card-title">Remote Links</div>
                      <pre class="stack-pre"><%= inspect(@selected_node.remote_links) %></pre>
                    <% end %>
                    <%= if @selected_node.remote_mon not in [nil, [], ""] do %>
                      <div class="card-title" style="margin-top:0.5rem;">Remote Monitors</div>
                      <pre class="stack-pre"><%= inspect(@selected_node.remote_mon) %></pre>
                    <% end %>
                    <%= if @selected_node.remote_mon_by not in [nil, [], ""] do %>
                      <div class="card-title" style="margin-top:0.5rem;">Remote Monitored By</div>
                      <pre class="stack-pre"><%= inspect(@selected_node.remote_mon_by) %></pre>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          <% end %>
        </tbody>
      </table>
    <% end %>
    """
  end

  defp fmt(nil), do: "—"
  defp fmt(v) when is_pid(v), do: v |> :erlang.pid_to_list() |> List.to_string()
  defp fmt(v) when is_list(v) do
    try do
      if List.ascii_printable?(v), do: List.to_string(v), else: inspect(v)
    rescue
      _ -> inspect(v)
    end
  end
  defp fmt(v), do: to_string(v)
end
