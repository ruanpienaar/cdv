defmodule CdvWeb.EtsLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "ets")
     |> assign(:sort, :memory)
     |> assign(:filter, "")
     |> assign_async(:tables, fn ->
       case DumpServer.ets_tables() do
         {:ok, list} -> {:ok, %{tables: sort_tables(list, :memory)}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  @impl true
  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)

    socket =
      case socket.assigns.tables do
        %AsyncResult{ok?: true, result: list} = async ->
          assign(socket, :tables, AsyncResult.ok(async, sort_tables(list, col_atom)))

        _ ->
          socket
      end

    {:noreply, assign(socket, :sort, col_atom)}
  end

  @impl true
  def handle_event("filter", %{"value" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp sort_tables(tables, :memory) do
    Enum.sort_by(tables, &parse_int(&1.memory), :desc)
  end
  defp sort_tables(tables, :size) do
    Enum.sort_by(tables, &parse_int(&1.size), :desc)
  end
  defp sort_tables(tables, :name) do
    Enum.sort_by(tables, &to_string(&1.name))
  end
  defp sort_tables(tables, _), do: tables

  defp parse_int(nil), do: 0
  defp parse_int(n) when is_integer(n), do: n
  defp parse_int({:bytes, n}) when is_integer(n), do: n
  defp parse_int({_, n}) when is_integer(n), do: n
  defp parse_int(s) do
    case Integer.parse(to_string(s)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp visible(tables, ""), do: tables
  defp visible(tables, filter) do
    f = String.downcase(filter)
    Enum.filter(tables, fn t ->
      String.contains?(String.downcase(searchable(t.id)), f) or
      String.contains?(String.downcase(searchable(t.name)), f) or
      String.contains?(String.downcase(searchable(t.pid)), f)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">ETS Tables</div>

    <.async_result :let={tables} assign={@tables}>
      <:loading><.loading label="Parsing ETS tables from dump…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>
      <.ets_table tables={tables} filter={@filter} sort={@sort} />
    </.async_result>
    """
  end

  attr :tables, :list, required: true
  attr :filter, :string, required: true
  attr :sort, :atom, required: true

  defp ets_table(assigns) do
    assigns = assign(assigns, :filtered, visible(assigns.tables, assigns.filter))

    ~H"""
    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by ID, name, owner…"
             phx-keyup="filter" phx-debounce="150" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@tables) %> tables</span>
    </div>

    <table class="cdv-table">
      <thead>
        <tr>
          <th>ID</th>
          <th class={th_class(@sort, :name)} phx-click="sort" phx-value-col="name">Name</th>
          <th>Type</th>
          <th>Owner PID</th>
          <th class={"num #{th_class(@sort, :size)}"} phx-click="sort" phx-value-col="size">Size</th>
          <th class={"num #{th_class(@sort, :memory)}"} phx-click="sort" phx-value-col="memory">Memory</th>
          <th>Named</th>
        </tr>
      </thead>
      <tbody>
        <%= for t <- @filtered do %>
          <tr>
            <td class="mono" style="font-size:11px;"><%= fmt(t.id) %></td>
            <td><%= fmt(t.name) %></td>
            <td class="mono" style="font-size:11px;"><%= fmt(t.data_type) %></td>
            <td class="mono" style="font-size:11px; color:var(--text-dim);"><%= fmt(t.pid) %></td>
            <td class="num"><%= format_int(parse_int(t.size)) %></td>
            <td class="num"><%= humanize_bytes(parse_int(t.memory)) %></td>
            <td style="font-size:11px;"><%= fmt(t.is_named) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp th_class(sort, col), do: if(sort == col, do: "sortable sorted", else: "sortable")

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
