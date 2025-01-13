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
      {DynamicSupervisor, name: NodeEx.Runtime.FlowsSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: NodeEx.Runtime.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
