defmodule BeamRED.Runtime.Supervisor do
  use Supervisor

  alias BeamRED.NodesManager
  alias BeamRED.Nodes

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      BeamRED.Runtime,
      BeamRED.Runtime.Storage,
      BeamRED.Runtime.Evaluator,
      {DynamicSupervisor, name: BeamRED.Runtime.FlowsSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: BeamRED.Runtime.Registry},
      BeamRED.MQTT.Server,
      {Phoenix.PubSub, name: BeamRED.PubSub}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
