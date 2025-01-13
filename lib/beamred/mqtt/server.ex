defmodule BeamRED.MQTT.Server do
  alias BeamRED.MQTT.Subscriptions
  use GenServer
  require Logger

  @type package_identifier() :: 0x0001..0xFFFF | nil
  @type topic() :: String.t()
  @type topic_filter() :: String.t()
  @type payload() :: binary() | nil

  @doc """
  Starts new MQTT server and links it to the current process
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec subscribe([topic_filter()]) :: :ok
  def subscribe(topics) do
    GenServer.call(__MODULE__, {:subscribe, topics})
  end

  @spec unsubscribe([topic_filter()] | :all) :: :ok
  def unsubscribe(topics) do
    GenServer.call(__MODULE__, {:unsubscribe, topics})
  end

  @spec publish(topic(), payload()) :: :ok
  def publish(topic, payload) do
    GenServer.cast(__MODULE__, {:publish, topic, payload})
  end

  @impl true
  def init(_) do
    {:ok, {Subscriptions.new(), %{}}}
  end

  @impl true
  def handle_call({:subscribe, topics}, {from, _}, {subscriptions, monitors}) do
    case Subscriptions.subscribe(subscriptions, from, topics) do
      :error ->
        {:reply, :error, subscriptions}

      new_subscriptions ->
        reference = Process.monitor(from)
        new_monitors = Map.put(monitors, from, reference)
        {:reply, :ok, {new_subscriptions, new_monitors}}
    end
  end

  @impl true
  def handle_call({:unsubscribe, topics}, {from, _}, {subscriptions, monitors} = state) do
    case Subscriptions.unsubscribe(subscriptions, from, topics) do
      :error ->
        {:reply, :error, state}

      {:empty, new_subscriptions} ->
        new_monitors =
          case Map.fetch(monitors, from) do
            {:ok, monitor_ref} ->
              Process.demonitor(monitor_ref)
              Map.delete(monitors, from)

            _ ->
              monitors
          end

        {:reply, :ok, {new_subscriptions, new_monitors}}

      {:not_empty, new_subscriptions} ->
        {:reply, :ok, {new_subscriptions, monitors}}
    end
  end

  @impl true
  def handle_cast({:publish, topic, payload}, {subscriptions, _} = state) do
    case Subscriptions.list_matched(subscriptions, topic) do
      :error ->
        {:noreply, state}

      pids ->
        for pid <- pids do
          Logger.debug(
            "Sending message published to topic #{topic} to subscriber #{inspect(pid)}"
          )

          send(pid, {:publish, topic, payload})
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, {subscriptions, monitors}) do
    Logger.info("Subscriber #{inspect(pid)} exited. Removing its subscriptions")
    new_monitors = Map.delete(monitors, pid)

    case Subscriptions.unsubscribe(subscriptions, pid, :all) do
      :error -> {:noreply, {subscriptions, new_monitors}}
      {_, new_subscriptions} -> {:noreply, {new_subscriptions, new_monitors}}
    end
  end
end
