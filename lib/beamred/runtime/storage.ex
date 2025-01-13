defmodule BeamRED.Runtime.Storage do
  # TODO use ets
  use GenServer

  @doc """
  Starts the storage process.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def save_flows(flows) do
    GenServer.call(__MODULE__, {:save_flows, flows})
  end

  def get_flows() do
    GenServer.call(__MODULE__, :get_flows)
  end

  def get_rev() do
    GenServer.call(__MODULE__, :get_rev)
  end

  def init(_) do
    {:ok, %{flows: [], rev: calc_rev([])}}
  end

  def handle_call({:save_flows, flows}, _from, state) do
    rev = calc_rev(flows)
    {:reply, rev, %{state | flows: flows, rev: rev}}
  end

  def handle_call(:get_flows, _from, state) do
    {:reply, {state.rev, state.flows}, state}
  end

  def handle_call(:get_rev, _from, state) do
    {:reply, state.rev, state}
  end

  defp calc_rev(flows) do
    binary = Jason.encode!(flows)
    :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
  end
end
