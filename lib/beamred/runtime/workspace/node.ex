defmodule BeamRED.Runtime.Workspace.Node do
  # Data structure representing a single node in a workspace.

  defstruct [
    :id,
    :flow_id,
    :module,
    :outputs,
    :status,
    :fields
  ]

  alias BeamRED.Utils
  alias BeamRED.Workspace.Flow

  @type id :: Utils.id()

  @type status_color :: :red | :green | :yellow | :blue | :grey
  @type status_shape :: :ring | :dot

  @type status :: {String.t(), status_shape(), status_color()}

  @type t :: %__MODULE__{
          id: id(),
          flow_id: Flow.id(),
          module: module(),
          outputs: list(id()),
          status: status() | nil,
          fields: map()
        }

  @doc """
  Returns a empty node.
  """
  @spec new(map()) :: t() | {:not_loaded, atom()}
  def new(node) do
    node_module = get_module(node["type"])

    if Code.ensure_loaded?(node_module) do
      %__MODULE__{
        id: node["id"],
        flow_id: node["z"],
        module: node_module,
        outputs: node["wires"],
        status: nil,
        fields: node
      }
    else
      {:not_loaded, node_module}
    end
  end

  @doc """
  Sets the status of the node.
  """
  @spec set_status(t(), status()) :: t()
  def set_status(node, status) do
    %{node | status: status}
  end

  defp get_module(type) do
    name =
      type
      |> String.replace("-", "_")
      |> Macro.camelize()
      |> String.to_atom()

    Module.concat([BeamRED.Nodes, name])
  end
end
