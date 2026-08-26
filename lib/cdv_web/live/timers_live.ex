defmodule CdvWeb.TimersLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "timers")
     |> assign(:filter, "")
     |> assign_async(:timers, fn ->
       case DumpServer.timers() do
         {:ok, list} -> {:ok, %{timers: list}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  @impl true
  def handle_event("filter", %{"value" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp visible(timers, ""), do: timers
  defp visible(timers, filter) do
    f = String.downcase(filter)
    Enum.filter(timers, fn t ->
      String.contains?(String.downcase(searchable(t.pid)), f) or
      String.contains?(String.downcase(searchable(t.name)), f) or
      String.contains?(String.downcase(searchable(t.msg)), f)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Timers</div>

    <.async_result :let={timers} assign={@timers}>
      <:loading><.loading label="Parsing timers from dump…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>
      <.timer_table timers={timers} filter={@filter} />
    </.async_result>
    """
  end

  attr :timers, :list, required: true
  attr :filter, :string, required: true

  defp timer_table(assigns) do
    assigns = assign(assigns, :filtered, visible(assigns.timers, assigns.filter))

    ~H"""
    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by PID, name, message…"
             phx-keyup="filter" phx-debounce="150" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@timers) %> timers</span>
    </div>

    <table class="cdv-table">
      <thead>
        <tr>
          <th>PID</th>
          <th>Name</th>
          <th>Message</th>
          <th class="num">Time (ms)</th>
        </tr>
      </thead>
      <tbody>
        <%= for t <- @filtered do %>
          <tr>
            <td class="mono" style="font-size:11px;">
              <.link navigate={~p"/process/#{pid_encode(t.pid)}"}>
                <%= fmt(t.pid) %>
              </.link>
            </td>
            <td><%= fmt(t.name) %></td>
            <td class="mono" style="font-size:11px; color:var(--text-dim);"><%= fmt(t.msg) %></td>
            <td class="num"><%= fmt(t.time) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
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

  defp pid_encode(pid), do: pid |> fmt() |> URI.encode()
end
