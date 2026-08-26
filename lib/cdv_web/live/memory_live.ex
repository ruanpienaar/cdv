defmodule CdvWeb.MemoryLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dump_status, DumpServer.status())
     |> assign(:current_page, "memory")
     |> assign_async(:mem, fn ->
       case DumpServer.memory() do
         {:ok, m} -> {:ok, %{mem: m}}
         {:error, e} -> {:error, e}
       end
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">Memory</div>

    <.async_result :let={mem} assign={@mem}>
      <:loading><.loading label="Reading memory summary…" /></:loading>
      <:failed :let={reason}><.async_failed reason={reason} /></:failed>

      <.kv_grid rows={[
        {"Total",          humanize_bytes(parse_int(mem[:total]))},
        {"Processes",      humanize_bytes(parse_int(mem[:processes]))},
        {"Processes Used", humanize_bytes(parse_int(mem[:processes_used]))},
        {"System",         humanize_bytes(parse_int(mem[:system]))},
        {"Atom",           humanize_bytes(parse_int(mem[:atom]))},
        {"Atom Used",      humanize_bytes(parse_int(mem[:atom_used]))},
        {"Binary",         humanize_bytes(parse_int(mem[:binary]))},
        {"Code",           humanize_bytes(parse_int(mem[:code]))},
        {"ETS",            humanize_bytes(parse_int(mem[:ets]))},
      ]} />
    </.async_result>
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
