defmodule CdvWeb.ModulesLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {mods, error} = fetch_mods(:current_size)

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "modules")
     |> assign(:mods, mods)
     |> assign(:error, error)
     |> assign(:sort, :current_size)
     |> assign(:filter, "")
     |> assign(:selected, nil)}
  end

  @impl true
  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)
    sorted = sort_mods(socket.assigns.mods, col_atom)
    {:noreply, socket |> assign(:mods, sorted) |> assign(:sort, col_atom)}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  @impl true
  def handle_event("select", %{"idx" => idx}, socket) do
    i = String.to_integer(idx)
    mod = Enum.at(socket.assigns.mods, i)
    selected = if socket.assigns.selected == i, do: nil, else: i
    {:noreply, socket |> assign(:selected, selected) |> assign(:selected_mod, mod)}
  end

  defp fetch_mods(sort) do
    case DumpServer.loaded_mods() do
      {:ok, list} -> {sort_mods(list, sort), nil}
      {:error, e} -> {[], e}
    end
  end

  defp sort_mods(mods, :current_size), do: Enum.sort_by(mods, &parse_int(&1.current_size), :desc)
  defp sort_mods(mods, :old_size),     do: Enum.sort_by(mods, &parse_int(&1.old_size), :desc)
  defp sort_mods(mods, :mod),          do: Enum.sort_by(mods, &to_string(&1.mod))
  defp sort_mods(mods, _),             do: mods

  defp parse_int(nil), do: 0
  defp parse_int(n) when is_integer(n), do: n
  defp parse_int(s) do
    case Integer.parse(to_string(s)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp visible(mods, ""), do: mods
  defp visible(mods, filter) do
    f = String.downcase(filter)
    Enum.filter(mods, fn m ->
      String.contains?(String.downcase(to_string(m.mod)), f)
    end)
  end

  @impl true
  def render(assigns) do
    filtered = visible(assigns.mods, assigns.filter)
    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="page-title">Modules</div>

    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by module name…"
             phx-keyup="filter" phx-value-q="" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@mods) %> modules</span>
    </div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

    <table class="cdv-table">
      <thead>
        <tr>
          <th class={th_class(@sort, :mod)} phx-click="sort" phx-value-col="mod">Module</th>
          <th class={"num #{th_class(@sort, :current_size)}"} phx-click="sort" phx-value-col="current_size">Current Size</th>
          <th class={"num #{th_class(@sort, :old_size)}"} phx-click="sort" phx-value-col="old_size">Old Size</th>
        </tr>
      </thead>
      <tbody>
        <%= for {m, idx} <- Enum.with_index(@filtered) do %>
          <tr class={if @selected == idx, do: "row-selected", else: ""} phx-click="select" phx-value-idx={idx} style="cursor:pointer;">
            <td class="mono"><%= fmt(m.mod) %></td>
            <td class="num"><%= humanize_bytes(parse_int(m.current_size)) %></td>
            <td class="num"><%= humanize_bytes(parse_int(m.old_size)) %></td>
          </tr>
          <%= if @selected == idx do %>
            <tr>
              <td colspan="3" style="padding:0;">
                <div class="card" style="margin:0.5rem 0;">
                  <%= if @selected_mod.current_attrib not in [nil, [], ""] do %>
                    <div class="card-title">Current Attributes</div>
                    <pre class="stack-pre"><%= fmt(@selected_mod.current_attrib) %></pre>
                  <% end %>
                  <%= if @selected_mod.current_comp_info not in [nil, [], ""] do %>
                    <div class="card-title" style="margin-top:0.5rem;">Current Compile Info</div>
                    <pre class="stack-pre"><%= fmt(@selected_mod.current_comp_info) %></pre>
                  <% end %>
                  <%= if @selected_mod.old_attrib not in [nil, [], ""] do %>
                    <div class="card-title" style="margin-top:0.5rem;">Old Attributes</div>
                    <pre class="stack-pre"><%= fmt(@selected_mod.old_attrib) %></pre>
                  <% end %>
                  <%= if @selected_mod.old_comp_info not in [nil, [], ""] do %>
                    <div class="card-title" style="margin-top:0.5rem;">Old Compile Info</div>
                    <pre class="stack-pre"><%= fmt(@selected_mod.old_comp_info) %></pre>
                  <% end %>
                </div>
              </td>
            </tr>
          <% end %>
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
  defp fmt(v) when is_tuple(v), do: inspect(v)
  defp fmt(v), do: to_string(v)
end
