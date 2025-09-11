defmodule TornexProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :tornex_proxy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:torngen_elixir_client, ">= 1.0.0"},
      {:tornex, "~> 0.4.0"},
      {:phoenix, "~> 1.7"},
      {:finch, "~> 0.20", only: :dev},
      {:bandit, "~> 1.8", only: :dev}
    ]
  end
end
