defmodule BeamRED.Runtime.Evaluator do
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    iex_server =
      if not IEx.started?() do
        :iex.start()
      else
        IEx.Broker.shell()
      end

    GenServer.start_link(__MODULE__, %{iex_server: iex_server}, name: __MODULE__)
  end

  @doc """
  Sends code to iex and waits for the evaluation response.
  """
  @spec evaluate_code(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def evaluate_code(code, opts \\ []) do
    GenServer.call(__MODULE__, {:evaluate, code, opts}, :infinity)
  end

  # Server Callbacks

  @impl true
  def init(%{iex_server: iex_server}) do
    state =
      %{
        caller: nil,
        ref: nil,
        iex_evaluator: nil,
        iex_server: iex_server
      }

    send(self(), :try_get_iex)

    {:ok, state}
  end

  @impl true
  def handle_call(_msg, _from, %{iex_evaluator: evaluator} = state) when is_nil(evaluator) do
    {:reply, {:error, :no_iex}, state}
  end

  def handle_call({:evaluate, code, _opts}, from, %{caller: nil} = state) do
    ref = make_ref()
    normalized_pid = :erlang.pid_to_list(self())
    normalized_ref = :erlang.ref_to_list(ref)

    code =
      """
      try do
        #{code}
      rescue
        error ->
          send(:erlang.list_to_pid(~c"#{normalized_pid}"), {:iex_reply, :erlang.list_to_ref(~c"#{normalized_ref}"), {:error, error}})
      else
        result ->
          send(:erlang.list_to_pid(~c"#{normalized_pid}"), {:iex_reply, :erlang.list_to_ref(~c"#{normalized_ref}"), {:ok, result}})
      end
      IEx.dont_display_result()
      """

    send_to_iex(state, code)
    {:noreply, %{state | caller: from, ref: ref}}
  end

  def handle_call({:evaluate, _code, _opts}, _from, state) do
    {:reply, {:error, :iex_busy}, state}
  end

  @impl true
  def handle_info({:iex_reply, ref, response}, %{caller: caller, ref: ref} = state) do
    GenServer.reply(caller, response)
    {:noreply, %{state | caller: nil, ref: nil}}
  end

  def handle_info(:try_get_iex, %{iex_server: iex_server} = state) do
    state =
      case IEx.Broker.evaluator(iex_server) do
        {nil, _} ->
          Process.send_after(self(), :try_get_iex, 100)
          state

        {iex_evaluator, iex_server} ->
          %{state | iex_evaluator: iex_evaluator, iex_server: iex_server}
      end

    {:noreply, state}
  end

  defp send_to_iex(state, code) do
    send(state.iex_evaluator, {:eval, state.iex_server, code, 1, ""})
  end
end
