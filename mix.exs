defmodule Cdv.MixProject do
  use Mix.Project

  def project do
    [
      app: :cdv,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Cdv.Application, []},
      extra_applications: [:logger, :runtime_tools, :observer]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end
end