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
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> allow_upload(:dump,
       accept: :any,
       max_entries: 1,
       max_file_size: 5_000_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :dump, ref)}
  end

  @impl true
  def handle_event("unload", _params, socket) do
    DumpServer.unload()
    status = DumpServer.status()
    {:noreply,
     socket
     |> assign(:dump_status, status)
     |> assign(:error, nil)}
  end

  def handle_progress(:dump, entry, socket) do
    cond do
      not entry.done? ->
        {:noreply, socket}

      upload_errors(socket.assigns.uploads.dump, entry) != [] ->
        {:noreply, socket}

      true ->
        {:noreply, load_dump(socket)}
    end
  end

  defp load_dump(socket) do
    socket = assign(socket, loading: true, error: nil)

    # crashdump_viewer keeps the path and re-opens the file lazily (e.g. for
    # general_info), so we copy the upload out of LiveView's tmp storage
    # (which gets deleted as soon as this callback returns) into a location
    # DumpServer owns for the lifetime of the loaded dump.
    [{dest, client_name}] =
      consume_uploaded_entries(socket, :dump, fn %{path: tmp_path}, entry ->
        dest =
          Path.join(
            upload_dir(),
            "#{System.unique_integer([:positive, :monotonic])}-#{Path.basename(entry.client_name)}"
          )

        File.cp!(tmp_path, dest)
        {:ok, {dest, entry.client_name}}
      end)

    case DumpServer.load(dest, client_name, true) do
      :ok ->
        status = DumpServer.status()

        socket
        |> assign(:dump_status, status)
        |> assign(:loading, false)
        |> push_navigate(to: "/general")

      {:error, msg} ->
        File.rm(dest)

        socket
        |> assign(:loading, false)
        |> assign(:error, "Not a valid crash dump: #{msg}")
    end
  end

  defp upload_dir do
    dir = Path.join(System.tmp_dir!(), "cdv_uploads")
    File.mkdir_p!(dir)
    dir
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
          <form phx-change="validate" style="display:flex; flex-direction:column; gap:0.75rem;">
            <.live_file_input upload={@uploads.dump} style="font-family:var(--font-mono); font-size:12px; color:var(--text-dim);" />

            <%= for entry <- @uploads.dump.entries do %>
              <div style="display:flex; align-items:center; gap:0.5rem; font-family:var(--font-mono); font-size:11px; color:var(--text-dim);">
                <span style="flex:1; word-break:break-all;"><%= entry.client_name %> — <%= entry.progress %>%</span>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  style="background:transparent; color:var(--muted); border:none; cursor:pointer; font-size:14px;"
                >
                  &times;
                </button>
              </div>
              <%= for err <- upload_errors(@uploads.dump, entry) do %>
                <div class="flash-error"><%= Phoenix.Naming.humanize(err) %></div>
              <% end %>
            <% end %>

            <%= if @loading do %>
              <div style="font-family:var(--font-mono); font-size:11px; color:var(--text-dim);">Checking crash dump…</div>
            <% end %>

            <%= if @error do %>
              <div class="flash-error"><%= @error %></div>
            <% end %>
          </form>
        </div>
      <% end %>
    </div>
    """
  end
end
