defmodule CdvWeb.MemoryLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {mem, error} = fetch_memory()

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "memory")
     |> assign(:mem, mem)
     |> assign(:error, error)}
  end

  defp fetch_memory do
    case DumpServer.memory() do
      {:ok, m} -> {m, nil}
      {:error, e} -> {nil, e}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Memory</div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

    <%= if @mem do %>
      <.kv_grid rows={[
        {"Total",          humanize_bytes(parse_int(@mem[:total]))},
        {"Processes",      humanize_bytes(parse_int(@mem[:processes]))},
        {"Processes Used", humanize_bytes(parse_int(@mem[:processes_used]))},
        {"System",         humanize_bytes(parse_int(@mem[:system]))},
        {"Atom",           humanize_bytes(parse_int(@mem[:atom]))},
        {"Atom Used",      humanize_bytes(parse_int(@mem[:atom_used]))},
        {"Binary",         humanize_bytes(parse_int(@mem[:binary]))},
        {"Code",           humanize_bytes(parse_int(@mem[:code]))},
        {"ETS",            humanize_bytes(parse_int(@mem[:ets]))},
      ]} />
    <% else %>
      <div style="color:var(--muted); font-family:var(--font-mono);">No dump loaded.</div>
    <% end %>
    """
  end

  defp parse_int(nil), do: nil
  defp parse_int(n) when is_integer(n), do: n
  defp parse_int(s) do
    case Integer.parse(to_string(s)) do
      {n, _} -> n
      :error -> nil
    end
  end
end
