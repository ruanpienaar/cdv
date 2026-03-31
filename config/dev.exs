import Config

config :cdv, CdvWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_64_chars_long_for_development_only!!",
  watchers: [],
  live_reload: [
    patterns: [
      ~r"lib/cdv_web/(live|views)/.*(ex)$",
      ~r"lib/cdv_web/components/.*(ex|heex)$"
    ]
  ]

config :logger, level: :debug
config :phoenix, :stacktrace_depth, 20