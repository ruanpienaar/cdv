import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing."

  port = String.to_integer(System.get_env("PORT") || "4000")
  host = System.get_env("CDV_HOST") || "localhost"

  config :cdv, CdvWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    url: [host: host, port: port]
end