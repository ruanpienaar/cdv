defmodule CdvWeb.Router do
  use CdvWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {CdvWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CdvWeb do
    pipe_through :browser

    live "/",            HomeLive,          :index
    live "/general",     GeneralLive,       :index
    live "/processes",   ProcessesLive,     :index
    live "/process/:pid", ProcessDetailLive, :show
    live "/ports",       PortsLive,         :index
    live "/port/:id",    PortDetailLive,    :show
    live "/ets",         EtsLive,           :index
    live "/timers",      TimersLive,        :index
    live "/memory",      MemoryLive,        :index
    live "/nodes",       NodesLive,         :index
    live "/modules",     ModulesLive,       :index
  end
end