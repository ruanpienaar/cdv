defmodule CdvWeb.RequireDump do
  @moduledoc """
  LiveView `on_mount` hook that keeps detail pages from rendering without a
  loaded crash dump — a fresh visit to e.g. `/processes` after a server
  restart (or before ever loading a dump) redirects to the upload page.
  """

  import Phoenix.LiveView

  alias Cdv.DumpServer

  def on_mount(:default, _params, _session, socket) do
    if DumpServer.status().status == :loaded do
      {:cont, socket}
    else
      {:halt, push_navigate(socket, to: "/")}
    end
  end
end
