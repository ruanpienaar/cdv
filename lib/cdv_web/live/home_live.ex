defmodule CdvWeb.HomeLive do
  use CdvWeb, :live_view
  alias Cdv.DumpServer

  @impl true
  def mount(_params, _session, socket) do
    status = DumpServer.status()
    {:ok,
     socket
     |> assign(:dump_status, status)
     |> assign(:current_page, "home")
     |> assign(:path, "")
     |> assign(:loading, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("set_path", %{"path" => path}, socket) do
    {:noreply, assign(socket, :path, path)}
  end

  @impl true
  def handle_event("load", %{"path" => path}, socket) do
    path = String.trim(path)
    if path == "" do
      {:noreply, assign(socket, :error, "Please enter a file path.")}
    else
      socket = assign(socket, loading: true, error: nil)
      case DumpServer.load(path) do
        :ok ->
          status = DumpServer.status()
          {:noreply,
           socket
           |> assign(:dump_status, status)
           |> assign(:loading, false)
           |> push_navigate(to: "/general")}

        {:error, msg} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:error, to_string(msg))}
      end
    end
  end

  @impl true
  def handle_event("unload", _params, socket) do
    DumpServer.unload()
    status = DumpServer.status()
    {:noreply,
     socket
     |> assign(:dump_status, status)
     |> assign(:path, "")
     |> assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="idle-center">
      <div style="font-family:var(--font-mono); font-size:22px; font-weight:700; color:var(--accent); letter-spacing:3px;">CDV</div>
      <div style="font-family:var(--font-mono); font-size:11px; color:var(--muted); margin-bottom:1rem;">Erlang Crash Dump Viewer</div>

      <%= if @dump_status.status == :loaded do %>
        <div class="card" style="min-width:420px; text-align:center;">
          <div style="font-family:var(--font-mono); font-size:12px; color:var(--text-dim); margin-bottom:0.5rem;">Currently loaded:</div>
          <div style="font-family:var(--font-mono); font-size:13px; color:var(--accent2); margin-bottom:1.25rem; word-break:break-all;"><%= @dump_status.filename %></div>
          <div style="display:flex; gap:0.75rem; justify-content:center;">
            <.link navigate={~p"/general"} style="font-family:var(--font-mono); font-size:12px; background:var(--accent); color:#fff; padding:8px 20px; border-radius:var(--radius); text-decoration:none;">
              View Dump
            </.link>
            <button phx-click="unload" style="font-family:var(--font-mono); font-size:12px; background:transparent; color:var(--muted); border:1px solid var(--border); padding:8px 20px; border-radius:var(--radius); cursor:pointer;">
              Unload
            </button>
          </div>
        </div>
      <% else %>
        <div class="card" style="min-width:420px;">
          <div style="font-family:var(--font-mono); font-size:11px; color:var(--text-dim); text-transform:uppercase; letter-spacing:1px; margin-bottom:1rem;">Load a crash dump</div>
          <form phx-submit="load" style="display:flex; flex-direction:column; gap:0.75rem;">
            <input
              name="path"
              class="search-box"
              style="width:100%;"
              placeholder="/path/to/erl_crash.dump"
              value={@path}
              phx-change="set_path"
              autofocus
            />
            <%= if @error do %>
              <div class="flash-error"><%= @error %></div>
            <% end %>
            <button
              type="submit"
              disabled={@loading}
              style="font-family:var(--font-mono); font-size:12px; background:var(--accent); color:#fff; border:none; padding:10px 20px; border-radius:var(--radius); cursor:pointer; opacity: if(@loading, 0.6, 1);"
            >
              <%= if @loading, do: "Loading…", else: "Load Dump" %>
            </button>
          </form>
        </div>
      <% end %>
    </div>
    """
  end
end
