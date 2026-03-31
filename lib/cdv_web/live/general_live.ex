defmodule CdvWeb.GeneralLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    info = if status.status == :loaded, do: fetch_info(), else: nil

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "general")
     |> assign(:info, info)}
  end

  defp fetch_info do
    case DumpServer.general_info() do
      {:ok, info} -> info
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">General Information</div>

    <%= if @info do %>
      <.kv_grid rows={[
        {"Created",        @info.created},
        {"Slogan",         @info.slogan},
        {"System Version", @info.system_vsn},
        {"Compile Time",   @info.compile_time},
        {"Node Name",      @info.node_name},
        {"Num Processes",  format_int(@info.num_procs)},
        {"Num Atoms",      format_int(@info.num_atoms)},
        {"Num ETS Tables", format_int(@info.num_ets)},
        {"Num Timers",     format_int(@info.num_timers)},
        {"Num Funs",       format_int(@info.num_fun)},
        {"Total Memory",   humanize_bytes(parse_int(@info.mem_tot))},
        {"Max Memory",     humanize_bytes(parse_int(@info.mem_max))},
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
