defmodule CdvWeb.ProcessDetailLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(%{"pid" => pid_encoded}, _session, socket) do
    pid_str = URI.decode(pid_encoded)

    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "processes")
     |> assign(:pid_str, pid_str)
     |> assign_async(:info, fn ->
       case DumpServer.proc_info(pid_str) do
         {:ok, p} -> {:ok, %{info: p}}
         {:error, e} -> {:error, e}
       end
     end)}
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

    <.async_result :let={info} assign={@info}>
      <:loading><.loading label="Reading process details…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>

      <.kv_grid rows={[
        {"PID",           fmt_list(info.pid)},
        {"Name",          info.name},
        {"State",         fmt_list(info.state)},
        {"Init Function", fmt_list(info.init_func)},
        {"Current Func",  fmt_list(info.current_func)},
        {"Memory",        humanize_bytes(info.memory)},
        {"Stack+Heap",    humanize_bytes(info.stack_heap)},
        {"Reductions",    format_int(info.reductions)},
        {"Msg Queue Len", info.msg_q_len},
        {"Run Queue",     info.run_queue},
      ]} />

      <%= if info.msg_q not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Message Queue</div>
          <pre class="stack-pre"><%= fmt_msg_q(info.msg_q) %></pre>
        </div>
      <% end %>

      <%= if info.stack_dump not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Stack Dump</div>
          <pre class="stack-pre"><%= fmt_stack_dump(info.stack_dump) %></pre>
        </div>
      <% end %>

      <%= if info.dict not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Process Dictionary</div>
          <pre class="stack-pre"><%= fmt_dict(info.dict) %></pre>
        </div>
      <% end %>

      <%= if info.links not in [nil, [], ""] do %>
        <div class="card">
          <div class="card-title">Links</div>
          <pre class="stack-pre"><%= inspect(info.links) %></pre>
        </div>
      <% end %>
    </.async_result>
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
  defp fmt_list(v) when is_tuple(v), do: inspect(v)
  defp fmt_list(v), do: to_string(v)

  # stack_dump is [{Label, Term}, ...] — one frame per line instead of one giant inspect line
  defp fmt_stack_dump(l) when is_list(l) do
    try do
      Enum.map_join(l, "\n", fn
        {label, term} -> "#{label}: #{inspect(term, pretty: true, width: 100)}"
        other -> inspect(other, pretty: true, width: 100)
      end)
    rescue
      _ -> inspect(l)
    end
  end
  defp fmt_stack_dump(v), do: fmt_list(v)

  # msg_q is [{Msg, Token}, ...] — one message per line
  defp fmt_msg_q(l) when is_list(l) do
    try do
      Enum.map_join(l, "\n", fn
        {msg, token} -> "#{inspect(msg, pretty: true, width: 100)} : #{inspect(token, pretty: true, width: 100)}"
        other -> inspect(other, pretty: true, width: 100)
      end)
    rescue
      _ -> inspect(l)
    end
  end
  defp fmt_msg_q(v), do: fmt_list(v)

  # dict is a list of terms — one entry per line
  defp fmt_dict(l) when is_list(l) do
    try do
      Enum.map_join(l, "\n", &inspect(&1, pretty: true, width: 100))
    rescue
      _ -> inspect(l)
    end
  end
  defp fmt_dict(v), do: fmt_list(v)
end