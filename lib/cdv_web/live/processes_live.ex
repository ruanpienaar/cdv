defmodule CdvWeb.ProcessesLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "processes")
     |> assign(:sort, :memory)
     |> assign(:filter, "")
     |> assign(:limit, default_row_limit())
     |> assign_async(:procs, fn ->
       case DumpServer.processes() do
         {:ok, list} -> {:ok, %{procs: sort_procs(list, :memory)}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  # Sorting happens on the already-loaded list — re-querying DumpServer would
  # re-parse the whole dump on every column click.
  @impl true
  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)

    socket =
      case socket.assigns.procs do
        %AsyncResult{ok?: true, result: list} = async ->
          assign(socket, :procs, AsyncResult.ok(async, sort_procs(list, col_atom)))

        _ ->
          socket
      end

    {:noreply, assign(socket, :sort, col_atom)}
  end

  @impl true
  def handle_event("filter", %{"value" => q}, socket) do
    {:noreply, socket |> assign(:filter, q) |> assign(:limit, default_row_limit())}
  end

  @impl true
  def handle_event("show_all", _params, socket) do
    {:noreply, assign(socket, :limit, :all)}
  end

  defp sort_procs(procs, :memory), do: Enum.sort_by(procs, &num(&1.memory), :desc)
  defp sort_procs(procs, :reductions), do: Enum.sort_by(procs, &num(&1.reductions), :desc)
  defp sort_procs(procs, :msg_q_len), do: Enum.sort_by(procs, &num(&1.msg_q_len), :desc)
  defp sort_procs(procs, :pid), do: Enum.sort_by(procs, &fmt_pid(&1.pid))
  defp sort_procs(procs, :name), do: Enum.sort_by(procs, &String.downcase(to_string(&1.name || "")))
  defp sort_procs(procs, _), do: procs

  defp num(n) when is_integer(n), do: n
  defp num(_), do: 0

  defp visible(procs, ""), do: procs
  defp visible(procs, filter) do
    f = String.downcase(filter)
    Enum.filter(procs, fn p ->
      String.contains?(String.downcase(searchable(p.pid)), f) or
      String.contains?(String.downcase(searchable(p.name)), f) or
      String.contains?(String.downcase(searchable(p.init_func)), f)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Processes</div>

    <.async_result :let={procs} assign={@procs}>
      <:loading><.loading label="Parsing processes from dump…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>
      <.proc_table procs={procs} filter={@filter} sort={@sort} limit={@limit} />
    </.async_result>
    """
  end

  attr :procs, :list, required: true
  attr :filter, :string, required: true
  attr :sort, :atom, required: true
  attr :limit, :any, required: true

  defp proc_table(assigns) do
    filtered = visible(assigns.procs, assigns.filter)

    assigns =
      assigns
      |> assign(:match_count, length(filtered))
      |> assign(:shown, limit_rows(filtered, assigns.limit))

    ~H"""
    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by PID, name, function…"
             phx-keyup="filter" phx-debounce="150" name="q" value={@filter} />
      <span class="row-count"><%= format_int(@match_count) %> / <%= format_int(length(@procs)) %> processes</span>
    </div>

    <.truncation_notice shown={length(@shown)} total={@match_count} noun="processes" />

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
        <%= for p <- @shown do %>
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
