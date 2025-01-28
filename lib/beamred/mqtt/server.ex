defmodule BeamRED.MQTT.Server do
  use GenServer
  alias Phoenix.PubSub
  alias BeamRED.MQTT.TopicTrie

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    PubSub.subscribe(BeamRED.PubSub, "topic_updates")
    {:ok, %{trie: TopicTrie.new()}}
  end

  # Public API
  def subscribe(topic) do
    :ok = PubSub.broadcast(BeamRED.PubSub, "topic_updates", {:subscribe, topic, self()})
  end

  def unsubscribe(topic) do
    :ok = PubSub.broadcast(BeamRED.PubSub, "topic_updates", {:unsubscribe, topic, self()})
  end

  def publish(topic, message) do
    :ok = PubSub.broadcast(BeamRED.PubSub, "topic_updates", {:publish, topic, message})
  end

  # GenServer callbacks
  def handle_info({:subscribe, topic, pid}, state) do
    trie = TopicTrie.add_subscription(state.trie, topic, pid)
    {:noreply, %{state | trie: trie}}
  end

  def handle_info({:unsubscribe, topic, pid}, state) do
    trie = TopicTrie.remove_subscription(state.trie, topic, pid)
    {:noreply, %{state | trie: trie}}
  end

  def handle_info({:publish, topic, message}, state) do
    subscribers = TopicTrie.find_subscribers(state.trie, topic)
    Enum.each(subscribers, &send(&1, {:message, topic, message}))
    {:noreply, state}
  end
end
