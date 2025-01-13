defmodule BeamRED.Runtime.Workspace.Flow do
  # Data structure representing a single flow in a workspace.

  defstruct [:id, :name, :nodes]

  alias BeamRED.Utils
  alias BeamRED.Runtime.Workspace.Node

  @type id :: Utils.id()

  @type t :: %__MODULE__{
          id: id(),
          name: String.t(),
          nodes: %{id() => Node.t()}
        }

  @doc """
  Returns a new flow.
  """
  @spec new(map()) :: t()
  def new(flow) do
    %__MODULE__{
      id: flow["id"],
      name: flow["name"],
      nodes: %{}
    }
  end

  @spec insert_node(t(), Node.id(), Node.t()) :: t()
  def insert_node(flow, node_id, node) do
    %{flow | nodes: Map.put(flow.nodes, node_id, node)}
  end
end
