defmodule BeamRED.Runtime.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BeamRED.Runtime,
      BeamRED.Runtime.Storage,
      BeamRED.Runtime.Evaluator,
      {DynamicSupervisor, name: BeamRED.Runtime.FlowsSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: BeamRED.Runtime.Registry},
      BeamRED.MQTT.Server,
      {Phoenix.PubSub, name: BeamRED.PubSub}
    ]

    opts = [strategy: :one_for_one, name: BeamRED.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
