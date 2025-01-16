defmodule BeamRED.Runtime do
  @moduledoc """
  Runtime implementation for NodeRed.

  NodeRed POSTs json specification of the whole workspace to the server.
  It also pushes information via header, if it's a node reload, flow reload or complete reload.
  It is the task of the runtime to figure out, which flows have changed.
  Since the datastructure is not nested the easiest approach is to directly compare the two
  structure inside a converter elixir structure.
  """
  defstruct [:evaluator, :workspace, :client_pids_with_id]

  use GenServer

  alias BeamRED.Runtime.Workspace
  alias BeamRED.User
  alias BeamRED.Utils

  @timeout :infinity
  @client_id "__server__"
  @anonymous_client_id "__anonymous__"

  @type t :: %{
          evaluator: pid(),
          workspace: Workspace.t(),
          client_pids_with_id: %{pid() => Workspace.client_id()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Register a new client.
  """
  @spec register_client(pid(), User.t()) :: {Workspace.t(), Workspace.client_id()}
  def register_client(client_pid, user) do
    GenServer.call(__MODULE__, {:register_client, client_pid, user}, @timeout)
  end

  @doc """
  Subscribes to runtimes messages.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe() do
    Phoenix.PubSub.subscribe(BeamRED.PubSub, "runtime")
  end

  @doc """
  Returns the current workspace structure.
  """
  @spec get_workspace() :: Workspace.t()
  def get_workspace() do
    GenServer.call(__MODULE__, :get_workspace, @timeout)
  end

  @doc """
  """
  @spec get_node_types() :: String.t()
  def get_node_types() do
    GenServer.call(__MODULE__, :get_node_types, @timeout)
  end

  @doc """
  """
  @spec get_node_pid(Workspace.Node.id()) :: {:ok, pid()} | :error
  def get_node_pid(id) do
    GenServer.call(__MODULE__, {:get_node_pid, id}, @timeout)
  end

  # TODO add rev type instead of String.t()
  @doc """
  """
  @spec get_workspace_rev() :: String.t()
  def get_workspace_rev() do
    GenServer.call(__MODULE__, :get_rev, @timeout)
  end

  @doc """
  """
  @spec get_flows() :: {String.t(), list()}
  def get_flows() do
    GenServer.call(__MODULE__, :get_flows, @timeout)
  end

  @doc """
  """
  @spec save_flows(list()) :: String.t()
  def save_flows(flows) do
    GenServer.call(__MODULE__, {:save_flows, flows})
  end

  @doc """
  """
  @spec get_workspace_rev() :: String.t()
  def get_workspace_rev() do
    GenServer.call(__MODULE__, :get_rev, @timeout)
  end

  @doc """
  """
  @spec add_node_type(module()) :: :ok
  def add_node_type(node_type) do
    GenServer.cast(__MODULE__, {:add_node_type, self(), node_type})
  end

  @doc """
  Adds new flow to workspace.
  """
  @spec insert_flow(map()) :: :ok
  def insert_flow(flow) do
    GenServer.cast(__MODULE__, {:insert_flow, self(), flow})
  end

  @doc """
  Adds new node to flow.
  """
  @spec insert_node(Flow.id(), map()) :: :ok
  def insert_node(flow_id, node) do
    GenServer.cast(__MODULE__, {:insert_node, self(), flow_id, node})
  end

  @doc """
  """
  @spec deploy_flows(map(), Workspace.deployment_type()) :: :ok
  def deploy_flows(json_flows, deployment_type) do
    GenServer.cast(__MODULE__, {:deploy_flows, self(), json_flows, deployment_type})
  end

  @doc """
  """
  @spec set_node_status(Workspace.Flow.id(), Workspace.Node.id(), Workspace.Node.status()) :: :ok
  def set_node_status(flow_id, node_id, status) do
    GenServer.cast(__MODULE__, {:set_node_status, self(), flow_id, node_id, status})
  end

  ## Callback

  @impl true
  def init(_opts) do
    workspace = default_workspace()

    state = %__MODULE__{
      workspace: workspace,
      client_pids_with_id: %{}
    }

    {:ok, state}
  end

  defp default_workspace() do
    Workspace.new()
  end

  @impl true
  def handle_call({:register_client, client_pid, user}, _from, state) do
    {state, client_id} =
      if client_id = state.client_pids_with_id[client_pid] do
        {state, client_id}
      else
        Process.monitor(client_pid)
        client_id = Utils.random_id()
        state = handle_operation(state, {:client_join, client_id, user})
        state = put_in(state.client_pids_with_id[client_pid], client_id)
        {state, client_id}
      end

    {:reply, {state.workspace, client_id}, state}
  end

  @impl true
  def handle_call(:get_workspace, _from, state) do
    {:reply, state.workspace, state}
  end

  def handle_call(:get_node_types, _from, state) do
    nodes =
      state.workspace.node_types
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.join("\n\n")

    {:reply, nodes, state}
  end

  def handle_call({:get_node_pid, id}, _from, state) do
    case Registry.lookup(BeamRED.Runtime.Registry, id) do
      [] ->
        {:reply, :error, state}

      [{pid, _}] ->
        {:reply, {:ok, pid}, state}
    end
  end

  def handle_call(:get_rev, _from, state) do
    rev = BeamRED.Runtime.Storage.get_rev()
    {:reply, rev, state}
  end

  def handle_call(:get_flows, _from, state) do
    flows = BeamRED.Runtime.Storage.get_flows()
    {:reply, flows, state}
  end

  def handle_call({:save_flows, flows}, _from, state) do
    rev = BeamRED.Runtime.Storage.save_flows(flows)
    {:reply, rev, state}
  end

  @impl true
  def handle_cast({:add_node_type, client_pid, node_type}, state) do
    client_id = client_id(state, client_pid)
    operation = {:add_node_type, client_id, node_type}
    {:noreply, handle_operation(state, operation)}
  end

  def handle_cast({:insert_flow, client_pid, flow}, state) do
    client_id = client_id(state, client_pid)
    # TODO: what happens if key id is not given?
    id = Map.get(flow, "id")
    operation = {:insert_flow, client_id, id, flow}
    {:noreply, handle_operation(state, operation)}
  end

  def handle_cast({:insert_node, client_pid, flow_id, node}, state) do
    client_id = client_id(state, client_pid)
    # TODO: what happens if key id is not given?
    node_id = Map.get(node, "id")
    operation = {:insert_node, client_id, flow_id, node_id, node}
    {:noreply, handle_operation(state, operation)}
  end

  def handle_cast({:deploy_flows, client_pid, json_flows, deployment_type}, state) do
    client_id = client_id(state, client_pid)
    operation = {:deploy_flows, client_id, json_flows, deployment_type}
    {:noreply, handle_operation(state, operation)}
  end

  def handle_cast({:set_node_status, client_pid, flow_id, node_id, status}, state) do
    client_id = client_id(state, client_pid)
    operation = {:set_node_status, client_id, flow_id, node_id, status}
    {:noreply, handle_operation(state, operation)}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _}, state) do
    state =
      if client_id = state.client_pids_with_id[pid] do
        handle_operation(state, {:client_leave, client_id})
      else
        state
      end

    {:noreply, state}
  end

  defp handle_operation(state, operation) do
    broadcast_operation(operation)

    case Workspace.apply_operation(state.workspace, operation) do
      {:ok, new_workspace, actions} ->
        %{state | workspace: new_workspace}
        |> after_operation(state, operation)
        |> handle_actions(actions)

      :error ->
        state
    end
  end

  defp after_operation(state, _prev_state, _operation), do: state

  defp handle_actions(state, actions) do
    Enum.reduce(actions, state, &handle_action(&2, &1))
  end

  defp handle_action(state, {:deploy, _deployment_type}) do
    # TODO use different deployment stratgies
    IEx.Helpers.respawn()

    DynamicSupervisor.which_children(BeamRED.Runtime.FlowsSupervisor)
    |> Enum.each(fn {:undefined, flow_sup_pid, :supervisor, _} ->
      :ok = DynamicSupervisor.terminate_child(BeamRED.Runtime.FlowsSupervisor, flow_sup_pid)
    end)

    Enum.each(state.workspace.flows, fn {flow_id, flow} ->
      {:ok, flow_sup_pid} =
        DynamicSupervisor.start_child(
          BeamRED.Runtime.FlowsSupervisor,
          {DynamicSupervisor, name: Utils.via_tuple(flow_id), strategy: :one_for_one}
        )

      Enum.each(flow.nodes, fn
        {_node_id, {:not_loaded, module}} ->
          IO.inspect(module, label: "Not loaded")

        {node_id, node} ->
          {:ok, _node_pid} =
            DynamicSupervisor.start_child(
              flow_sup_pid,
              {node.module, name: Utils.via_tuple(node_id), node: node}
            )
            |> IO.inspect(label: "Start node")
      end)
    end)

    state
  end

  defp handle_action(state, _action), do: state

  defp broadcast_operation(operation) do
    broadcast_message({:operation, operation})
  end

  defp broadcast_error(error) do
    broadcast_message({:error, error})
  end

  defp broadcast_message(message) do
    Phoenix.PubSub.broadcast(BeamRED.PubSub, "runtime", message)
  end

  defp client_id(state, client_pid) do
    state.client_pids_with_id[client_pid] || @anonymous_client_id
  end
end
