defmodule CdvWeb.ProcessDetailLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer
  import CdvWeb.CoreComponents

  @impl true
  def mount(%{"pid" => pid_encoded}, _session, socket) do
    pid_str = URI.decode(pid_encoded)
    status = DumpServer.status()

    {info, error} =
      case DumpServer.proc_info(pid_str) do
        {:ok, p} -> {p, nil}
        {:error, e} -> {nil, e}
      end

    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "processes")
     |> assign(:pid_str, pid_str)
     |> assign(:info, info)
     |> assign(:error, error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="margin-bottom:1rem;">
      <.link navigate={~p"/processes"} style="font-family:var(--font-mono); font-size:11px; color:var(--muted);">
        ← Processes
      </.link>
    </div>
    <div class="page-title">Process <span style="color:var(--blue);"><%= @pid_str %></span></div>

    <%= if @error do %>
      <div class="flash-error"><%= @error %></div>
    <% end %>

    <%= if @info do %>
      <.kv_grid rows={[
        {"PID",           fmt_list(@info.pid)},
        {"Name",          @info.name},
        {"State",         fmt_list(@info.state)},
        {"Init Function", fmt_list(@info.init_func)},
        {"Current Func",  fmt_list(@info.current_func)},
        {"Memory",        humanize_bytes(@info.memory)},
        {"Stack+Heap",    humanize_bytes(@info.stack_heap)},
        {"Reductions",    format_int(@info.reductions)},
        {"Msg Queue Len", @info.msg_q_len},
        {"Run Queue",     @info.run_queue},
      ]} />

      <%= if @info.msg_q not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Message Queue</div>
          <pre class="stack-pre"><%= fmt_list(@info.msg_q) %></pre>
        </div>
      <% end %>

      <%= if @info.stack_dump not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Stack Dump</div>
          <pre class="stack-pre"><%= fmt_list(@info.stack_dump) %></pre>
        </div>
      <% end %>

      <%= if @info.dict not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Process Dictionary</div>
          <pre class="stack-pre"><%= fmt_list(@info.dict) %></pre>
        </div>
      <% end %>

      <%= if @info.links not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Links</div>
          <pre class="stack-pre"><%= inspect(@info.links) %></pre>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp fmt_list(nil), do: "—"
  defp fmt_list(v) when is_pid(v), do: v |> :erlang.pid_to_list() |> List.to_string()
  defp fmt_list(l) when is_list(l) do
    try do
      if List.ascii_printable?(l), do: List.to_string(l), else: inspect(l)
    rescue
      _ -> inspect(l)
    end
  end
  defp fmt_list(v), do: to_string(v)
end