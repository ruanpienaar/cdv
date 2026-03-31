defmodule Cdv.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Cdv.PubSub},
      CdvWeb.Endpoint,
      Cdv.DumpServer
    ]

    opts = [strategy: :one_for_one, name: Cdv.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    CdvWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end