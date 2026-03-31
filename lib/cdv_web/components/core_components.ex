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