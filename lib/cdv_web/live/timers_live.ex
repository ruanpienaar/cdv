defmodule CdvWeb.TimersLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {timers, error} = fetch_timers()

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "timers")
     |> assign(:timers, timers)
     |> assign(:error, error)
     |> assign(:filter, "")}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, assign(socket, :filter, q)}
  end

  defp fetch_timers do
    case DumpServer.timers() do
      {:ok, list} -> {list, nil}
      {:error, e} -> {[], e}
    end
  end

  defp visible(timers, ""), do: timers
  defp visible(timers, filter) do
    f = String.downcase(filter)
    Enum.filter(timers, fn t ->
      String.contains?(String.downcase(to_string(t.pid)), f) or
      String.contains?(String.downcase(to_string(t.name)), f) or
      String.contains?(String.downcase(to_string(t.msg)), f)
    end)
  end

  @impl true
  def render(assigns) do
    filtered = visible(assigns.timers, assigns.filter)
    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="page-title">Timers</div>

    <div class="table-toolbar">
      <input class="search-box" placeholder="Filter by PID, name, message…"
             phx-keyup="filter" phx-value-q="" name="q" value={@filter} />
      <span class="row-count"><%= length(@filtered) %> / <%= length(@timers) %> timers</span>
    </div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

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
