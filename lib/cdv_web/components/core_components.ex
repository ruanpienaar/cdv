defmodule CdvWeb.CoreComponents do
  use Phoenix.Component

  def state_badge(assigns) do
    cls = badge_class(assigns[:state] || "")
    assigns = assign(assigns, :cls, cls)
    ~H"""
    <span class={"badge #{@cls}"}><%= @state %></span>
    """
  end

  defp badge_class(state) do
    case String.downcase(to_string(state)) do
      "running"   -> "badge-running"
      "waiting"   -> "badge-waiting"
      "exiting"   -> "badge-exiting"
      "garbing"   -> "badge-garbing"
      _           -> "badge-other"
    end
  end

  def humanize_bytes(nil), do: "—"
  def humanize_bytes(b) when is_integer(b) and b < 0, do: "—"
  def humanize_bytes(b) when is_integer(b) do
    cond do
      b >= 1_073_741_824 -> "#{Float.round(b / 1_073_741_824, 1)} GB"
      b >= 1_048_576     -> "#{Float.round(b / 1_048_576, 1)} MB"
      b >= 1_024         -> "#{Float.round(b / 1_024, 1)} KB"
      true               -> "#{b} B"
    end
  end
  def humanize_bytes(b), do: to_string(b)

  def format_int(nil), do: "—"
  def format_int(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
  def format_int(n), do: to_string(n)

  @doc """
  Best-effort string for filtering. Unlike `to_string/1` this never raises on
  the shapes the dump parser hands back — module names and port ids arrive as
  tuples, and `String.Chars` has no tuple implementation.
  """
  def searchable(nil), do: ""
  def searchable(v) when is_binary(v), do: v
  def searchable(v) when is_atom(v), do: Atom.to_string(v)
  def searchable(v) when is_integer(v), do: Integer.to_string(v)
  def searchable(v) when is_pid(v), do: v |> :erlang.pid_to_list() |> List.to_string()

  def searchable(v) when is_list(v) do
    try do
      if List.ascii_printable?(v), do: List.to_string(v), else: inspect(v)
    rescue
      _ -> inspect(v)
    end
  end

  def searchable(v), do: inspect(v)

  attr :label, :string, default: "Loading…"
  def loading(assigns) do
    ~H"""
    <div class="loading-panel">
      <span class="spinner"></span>
      <span><%= @label %></span>
    </div>
    """
  end

  @doc """
  Renders an async failure. `reason` is whatever `assign_async/3` returned in
  its `{:error, reason}` tuple, or an `{:exit, term}` if the task itself died.
  """
  attr :reason, :any, required: true
  def async_failed(assigns) do
    ~H"""
    <div class="flash-error"><%= format_reason(@reason) %></div>
    """
  end

  # assign_async reports a returned {:error, reason} as-is, and a crashed task
  # as {:exit, reason}.
  defp format_reason({:error, reason}), do: format_reason(reason)
  defp format_reason({:exit, reason}), do: "Failed to read dump: #{inspect(reason)}"
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  @doc """
  Default number of table rows rendered before truncating.

  A large dump has thousands of processes and modules; rendering them all costs
  ~50k DOM nodes and several MB of HTML per page view, and every filter
  keystroke re-renders the lot. Nobody scrolls 5000 rows — they filter — so we
  render a window and offer an explicit escape hatch.
  """
  def default_row_limit, do: 500

  attr :shown, :integer, required: true
  attr :total, :integer, required: true
  attr :noun, :string, default: "rows"

  def truncation_notice(assigns) do
    ~H"""
    <%= if @shown < @total do %>
      <div style="font-family:var(--font-mono); font-size:11px; color:var(--text-dim); padding:0.75rem 0; display:flex; align-items:center; gap:0.75rem;">
        <span>Showing first <%= format_int(@shown) %> of <%= format_int(@total) %> <%= @noun %> — filter to narrow.</span>
        <button phx-click="show_all"
                style="font-family:var(--font-mono); font-size:11px; background:transparent; color:var(--accent2); border:1px solid var(--border); padding:4px 10px; border-radius:var(--radius); cursor:pointer;">
          Show all
        </button>
      </div>
    <% end %>
    """
  end

  @doc "Takes `limit` rows, where `:all` means no cap."
  def limit_rows(rows, :all), do: rows
  def limit_rows(rows, n) when is_integer(n), do: Enum.take(rows, n)

  attr :rows, :list, required: true
  def kv_grid(assigns) do
    ~H"""
    <div class="kv-grid">
      <%= for {key, val} <- @rows do %>
        <div class="kv-key"><%= key %></div>
        <div class="kv-val mono"><%= display_val(val) %></div>
      <% end %>
    </div>
    """
  end

  defp display_val(nil), do: "—"
  defp display_val([]), do: "—"
  defp display_val(v) when is_list(v) do
    try do
      if List.ascii_printable?(v), do: List.to_string(v), else: inspect(v)
    rescue
      _ -> inspect(v)
    end
  end
  defp display_val(v) when is_integer(v) and v < 0, do: "—"
  defp display_val(v), do: to_string(v)
end