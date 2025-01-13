defmodule BeamRED.Runtime.Workspace.Changes do
  defstruct [
    :added_nodes,
    :removed_nodes,
    :changed_nodes,
    :added_flows,
    :removed_flows,
    :changed_flows
  ]
end
