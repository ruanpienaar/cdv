defmodule CdvWeb.PortDetailLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(%{"id" => id_encoded}, _session, socket) do
    id_str = URI.decode(id_encoded)
    status = DumpServer.status()

    {info, error} =
      case DumpServer.port_info(id_str) do
        {:ok, p} -> {p, nil}
        {:error, e} -> {nil, e}
      end

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "ports")
     |> assign(:id_str, id_str)
     |> assign(:info, info)
     |> assign(:error, error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="margin-bottom:1rem;">
      <.link navigate={~p"/ports"} style="font-family:var(--font-mono); font-size:11px; color:var(--muted);">
        ← Ports
      </.link>
    </div>
    <div class="page-title">Port <span style="color:var(--blue);"><%= @id_str %></span></div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

    <%= if @info do %>
      <.kv_grid rows={[
        {"ID",        fmt(@info.id)},
        {"Name",      fmt(@info.name)},
        {"Connected", fmt(@info.connected)},
        {"Controls",  fmt(@info.controls)},
        {"Input",     fmt(@info.input)},
        {"Output",    fmt(@info.output)},
        {"Queue",     fmt(@info.queue)},
        {"Slot",      fmt(@info.slot)},
      ]} />

      <%= if @info.links not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Links</div>
          <pre class="stack-pre"><%= inspect(@info.links) %></pre>
        </div>
      <% end %>

      <%= if @info.monitors not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Monitors</div>
          <pre class="stack-pre"><%= inspect(@info.monitors) %></pre>
        </div>
      <% end %>
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
  defp fmt(v), do: to_string(v)
end
