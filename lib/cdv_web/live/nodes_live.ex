defmodule CdvWeb.NodesLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "nodes")
     |> assign(:selected, nil)
     |> assign(:selected_node, nil)
     |> assign_async(:nodes, fn ->
       case DumpServer.nodes() do
         {:ok, list} -> {:ok, %{nodes: list}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  @impl true
  def handle_event("select", %{"idx" => idx}, socket) do
    i = String.to_integer(idx)

    node =
      case socket.assigns.nodes do
        %AsyncResult{ok?: true, result: list} -> Enum.at(list, i)
        _ -> nil
      end

    selected = if socket.assigns.selected == i, do: nil, else: i
    {:noreply, socket |> assign(:selected, selected) |> assign(:selected_node, node)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Nodes</div>

    <.async_result :let={nodes} assign={@nodes}>
      <:loading><.loading label="Reading distribution info…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>
      <.node_table nodes={nodes} selected={@selected} selected_node={@selected_node} />
    </.async_result>
    """
  end

  attr :nodes, :list, required: true
  attr :selected, :integer, required: true
  attr :selected_node, :any, required: true

  defp node_table(assigns) do
    ~H"""
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
  defp fmt(v) when is_tuple(v), do: inspect(v)
  defp fmt(v) when is_binary(v) or is_atom(v) or is_number(v), do: to_string(v)
  defp fmt(v), do: inspect(v)
end
