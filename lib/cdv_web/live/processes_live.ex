defmodule CdvWeb.ProcessesLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {procs, error} = fetch_procs(:memory)

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "processes")
     |> assign(:procs, procs)
     |> assign(:error, error)
     |> assign(:sort, :memory)
     |> assign(:filter, "")}
  end

  @impl true
  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)
    {procs, error} = fetch_procs(col_atom)
    {:noreply, socket |> assign(:procs, procs) |> assign(:sort, col_atom) |> assign(:error, error)}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp fetch_procs(sort) do
    case DumpServer.processes(sort: sort) do
      {:ok, list} -> {list, nil}
      {:error, e} -> {[], e}
    end
  end

  defp visible(procs, ""), do: procs
  defp visible(procs, filter) do
    f = String.downcase(filter)
    Enum.filter(procs, fn p ->
      String.contains?(String.downcase(to_string(p.pid)), f) or
      String.contains?(String.downcase(to_string(p.name)), f) or
      String.contains?(String.downcase(to_string(p.init_func)), f)
    end)
  end

  @impl true
  def render(assigns) do
    filtered = visible(assigns.procs, assigns.filter)
    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="page-title">Processes</div>

    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by PID, name, function…"
             phx-keyup="filter" phx-value-q="" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@procs) %> processes</span>
    </div>

    <table class="cdv-table">
      <thead>
        <tr>
          <th class={th_class(@sort, :pid)}     phx-click="sort" phx-value-col="pid">PID</th>
          <th class={th_class(@sort, :name)}    phx-click="sort" phx-value-col="name">Name</th>
          <th class={th_class(@sort, :state)}>State</th>
          <th class={th_class(@sort, :memory)}  phx-click="sort" phx-value-col="memory">Memory</th>
          <th class={th_class(@sort, :reductions)} phx-click="sort" phx-value-col="reductions">Reductions</th>
          <th class={th_class(@sort, :msg_q_len)} phx-click="sort" phx-value-col="msg_q_len">Msg Queue</th>
          <th>Current Function</th>
        </tr>
      </thead>
      <tbody>
        <%= for p <- @filtered do %>
          <tr>
            <td class="pid-col">
              <.link navigate={~p"/process/#{pid_encode(p.pid)}"}>
                <%= fmt_pid(p.pid) %>
              </.link>
            </td>
            <td class="name-col"><%= p.name || "" %></td>
            <td><.state_badge state={fmt_state(p.state)} /></td>
            <td class="num"><%= humanize_bytes(p.memory) %></td>
            <td class="num"><%= format_int(p.reductions) %></td>
            <td class={"num #{msgq_class(p.msg_q_len)}"}><%= p.msg_q_len %></td>
            <td class="mono" style="font-size:11px; color:var(--text-dim);"><%= p.current_func %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp th_class(sort, col) do
    base = "sortable"
    if sort == col, do: base <> " sorted", else: base
  end

  defp fmt_pid(pid) when is_pid(pid),  do: pid |> :erlang.pid_to_list() |> List.to_string()
  defp fmt_pid(pid) when is_list(pid), do: List.to_string(pid)
  defp fmt_pid(pid), do: to_string(pid)

  defp fmt_state(s) when is_list(s), do: List.to_string(s)
  defp fmt_state(s), do: to_string(s)

  defp pid_encode(pid), do: pid |> fmt_pid() |> URI.encode()

  defp msgq_class(n) when is_integer(n) and n > 1000, do: "hi"
  defp msgq_class(n) when is_integer(n) and n > 100, do: "med"
  defp msgq_class(_), do: ""
end