defmodule BeamRED.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamred_runtime,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {BeamRED.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0"}
    ]
  end
end
