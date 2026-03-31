defmodule CdvWeb.EtsLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {tables, error} = fetch_tables()

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "ets")
     |> assign(:tables, tables)
     |> assign(:error, error)
     |> assign(:sort, :memory)
     |> assign(:filter, "")}
  end

  @impl true
  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)
    sorted = sort_tables(socket.assigns.tables, col_atom)
    {:noreply, socket |> assign(:tables, sorted) |> assign(:sort, col_atom)}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp fetch_tables do
    case DumpServer.ets_tables() do
      {:ok, list} -> {sort_tables(list, :memory), nil}
      {:error, e} -> {[], e}
    end
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
      String.contains?(String.downcase(to_string(t.id)), f) or
      String.contains?(String.downcase(to_string(t.name)), f) or
      String.contains?(String.downcase(to_string(t.pid)), f)
    end)
  end

  @impl true
  def render(assigns) do
    filtered = visible(assigns.tables, assigns.filter)
    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="page-title">ETS Tables</div>

    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by ID, name, owner…"
             phx-keyup="filter" phx-value-q="" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@tables) %> tables</span>
    </div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

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
