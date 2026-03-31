import Config

config :cdv, CdvWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: CdvWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Cdv.PubSub,
  live_view: [signing_salt: "cdv_lv_salt_123"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"