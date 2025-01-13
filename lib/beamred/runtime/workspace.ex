defmodule BeamRED.Runtime.Workspace do
  # Data structure representing a NodeRed workspace.
  #
  # A workspace is the datastructure NodeRed outputs as a json file.

  defstruct [
    :node_types,
    :flows,
    :changes,
    :revision,
    :dirty,
    :clients_map
  ]

  alias BeamRED.Utils
  alias BeamRED.User
  alias BeamRED.Runtime.Workspace.Flow
  alias BeamRED.Runtime.Workspace.Node
  alias BeamRED.Runtime.Workspace.Changes

  @type t :: %__MODULE__{
          node_types: %{module() => String.t()},
          flows: %{id() => Flow.t()},
          changes: Changes.t(),
          revision: String.t(),
          dirty: boolean(),
          clients_map: %{client_id() => User.id()}
        }

  @type id :: Utils.id()
  @type client_id :: Utils.id()
  @type deployment_type :: :full | :flows | :nodes | :reload

  @type operation ::
          {:client_join, client_id(), User.t()}
          | {:client_leave, client_id()}
          | {:add_node_type, client_id(), module()}
          | {:insert_flow, client_id(), Flow.id(), map()}
          | {:insert_node, client_id(), Flow.id(), Node.id(), map()}
          | {:delete_flow, client_id(), Flow.id()}
          | {:delete_node, Node.id()}
          | {:deploy_flows, client_id(), map(), deployment_type()}
          | {:set_node_status, client_id(), Flow.id(), Node.id(), Node.status()}

  @type action ::
          {:start_evaluation, Flow.t()}
          | {:stop_evaluation, Flow.t()}
          | {:deploy, deployment_type()}

  @doc """
  Returns a blank workspace.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      node_types: %{},
      flows: %{},
      revision: :crypto.hash(:sha256, "[]") |> Base.encode16(case: :lower),
      dirty: true,
      clients_map: %{}
    }
  end

  @doc """
  """
  @spec apply_operation(t(), operation()) :: {:ok, t(), list(action())} | :error
  def apply_operation(workspace, operation)

  def apply_operation(workspace, {:client_join, client_id, user}) do
    with false <- Map.has_key?(workspace.clients_map, client_id) do
      workspace
      |> with_actions()
      |> client_join(client_id, user)
      |> wrap_ok()
    else
      _ -> :error
    end
  end

  def apply_operation(workspace, {:client_leave, client_id}) do
    with true <- Map.has_key?(workspace.clients_map, client_id) do
      workspace
      |> with_actions()
      |> client_leave(client_id)
      # |> app_maybe_terminate()
      |> wrap_ok()
    else
      _ -> :error
    end
  end

  def apply_operation(workspace, {:add_node_type, _client_id, node_type}) do
    with true <- Utils.has_function?(node_type, :__node_definition__, 0) do
      workspace
      |> with_actions()
      |> add_node_type(node_type, node_type.__node_definition__)
      |> wrap_ok()
    else
      _ -> :error
    end
  end

  def apply_operation(workspace, {:insert_flow, _client_id, id, flow}) do
    flow = Flow.new(flow)

    workspace
    |> with_actions()
    |> insert_flow(id, flow)
    |> set_dirty()
    |> wrap_ok()
  end

  def apply_operation(workspace, {:insert_node, _client_id, flow_id, node_id, node}) do
    node = Node.new(node)

    workspace
    |> with_actions()
    |> insert_node(flow_id, node_id, node)
    |> set_dirty()
    |> wrap_ok()
  end

  def apply_operation(workspace, {:deploy_flows, _client_id, json_flows, deployment_type}) do
    flows =
      json_flows
      |> Enum.filter(fn f -> f["type"] == "tab" end)
      |> Enum.reduce(%{}, fn f, flows ->
        flow_id = f["id"]
        flow = Flow.new(f)
        Map.put(flows, flow_id, flow)
      end)

    flows =
      json_flows
      |> Enum.reject(fn f -> f["type"] in ["tab", "group", "subnode"] end)
      |> Enum.reduce(flows, fn n, flows ->
        node_id = n["id"]
        flow_id = n["z"]
        node = Node.new(n)
        put_in(flows, [Access.key(flow_id), Access.key(:nodes), Access.key(node_id)], node)
      end)

    # TODO save changes

    workspace
    |> with_actions()
    |> update_flows(flows)
    |> add_action({:deploy, deployment_type})
    |> set_dirty()
    |> wrap_ok()
  end

  def apply_operation(workspace, {:set_node_status, _client_id, flow_id, node_id, status}) do
    workspace
    |> with_actions()
    |> set_node_status(flow_id, node_id, status)
    |> set_dirty()
    |> wrap_ok()
  end

  defp add_action({workspace, actions}, action) do
    {workspace, actions ++ [action]}
  end

  defp with_actions(workspace, actions \\ []), do: {workspace, actions}

  defp wrap_ok({workspace, actions}), do: {:ok, workspace, actions}

  defp set!({workspace, actions}, changes) do
    changes
    |> Enum.reduce(workspace, fn {key, value}, info ->
      Map.replace!(info, key, value)
    end)
    |> with_actions(actions)
  end

  defp set_dirty(workspace_actions, dirty \\ true) do
    set!(workspace_actions, dirty: dirty)
  end

  defp client_join({workspace, _} = workspace_actions, client_id, user) do
    workspace_actions
    |> set!(clients_map: Map.put(workspace.clients_map, client_id, user.id))
  end

  defp client_leave({workspace, _} = workspace_actions, client_id) do
    {_user_id, clients_map} = Map.pop(workspace.clients_map, client_id)

    workspace_actions
    |> set!(clients_map: clients_map)
  end

  defp add_node_type({workspace, _} = workspace_actions, node_type, definition) do
    workspace_actions
    |> set!(node_types: Map.put(workspace.node_types, node_type, definition))
  end

  defp insert_flow({workspace, _} = workspace_actions, id, flow) do
    flows = Map.put(workspace.flows, id, flow)

    workspace_actions
    |> set!(flows: flows)
  end

  defp insert_node({workspace, _} = workspace_actions, flow_id, node_id, node) do
    flows =
      update_in(workspace.flows, [Access.key(flow_id)], fn flow ->
        %{flow | nodes: Map.put(flow.nodes, node_id, node)}
      end)

    workspace_actions
    |> set!(flows: flows)
  end

  defp update_flows({workspace, _} = workspace_actions, flows) do
    workspace_actions
    |> set!(flows: flows)
  end

  defp set_node_status({workspace, _} = workspace_actions, flow_id, node_id, status) do
    flows =
      update_in(
        workspace.flows,
        [Access.key(flow_id), Access.key(:nodes), Access.key(node_id)],
        fn node ->
          Node.set_status(node, status)
        end
      )

    workspace_actions
    |> set!(flows: flows)
  end
end
