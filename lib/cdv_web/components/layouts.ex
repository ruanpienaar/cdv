defmodule CdvWeb.Layouts do
  use CdvWeb, :html

  embed_templates "layouts/*"

  def nav_class(current, page) do
    if current == page, do: "nav-link active", else: "nav-link"
  end
end