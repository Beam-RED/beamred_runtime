defmodule BeamRED.MQTT.TopicTrie do
  defstruct children: %{}, wildcards: %{single: MapSet.new(), multi: MapSet.new()}, subscribers: MapSet.new()

  def new, do: %__MODULE__{}

  def add_subscription(trie, topic, subscriber_pid) do
    parts = split_topic(topic)
    do_add(trie, parts, subscriber_pid)
  end

  def remove_subscription(trie, topic, subscriber_pid) do
    parts = split_topic(topic)
    do_remove(trie, parts, subscriber_pid)
  end

  def find_subscribers(trie, topic) do
    parts = split_topic(topic)
    do_find(trie, parts, MapSet.new())
  end

  # Helper to split and validate topic
  defp split_topic(topic) do
    parts = String.split(topic, "/")

    if topic_valid?(parts) do
      parts
    else
      raise ArgumentError, "Invalid topic format: #{topic}"
    end
  end

  defp topic_valid?(parts) do
    Enum.all?(parts, fn part -> part != "" end)
  end

  # Add subscription helpers
  defp do_add(trie, [], pid), do: %{trie | subscribers: MapSet.put(trie.subscribers, pid)}

  defp do_add(trie, ["+" | rest], pid) do
    trie = %{trie | wildcards: %{trie.wildcards | single: MapSet.put(trie.wildcards.single, pid)}}
    do_add(trie, rest, pid)
  end

  defp do_add(trie, ["#" | _], pid) do
    %{trie | wildcards: %{trie.wildcards | multi: MapSet.put(trie.wildcards.multi, pid)}}
  end

  defp do_add(trie, [part | rest], pid) do
    child = Map.get(trie.children, part, new())
    updated_child = do_add(child, rest, pid)
    %{trie | children: Map.put(trie.children, part, updated_child)}
  end

  # Remove subscription helpers
  defp do_remove(trie, [], pid), do: %{trie | subscribers: MapSet.delete(trie.subscribers, pid)}

  defp do_remove(trie, ["+" | rest], pid) do
    updated = %{trie | wildcards: %{trie.wildcards | single: MapSet.delete(trie.wildcards.single, pid)}}
    do_remove(updated, rest, pid)
  end

  defp do_remove(trie, ["#" | _], pid) do
    %{trie | wildcards: %{trie.wildcards | multi: MapSet.delete(trie.wildcards.multi, pid)}}
  end

  defp do_remove(trie, [part | rest], pid) do
    case Map.get(trie.children, part) do
      nil -> trie
      child ->
        updated_child = do_remove(child, rest, pid)
        if MapSet.size(updated_child.subscribers) == 0 and
             Enum.empty?(updated_child.children) and
             MapSet.size(updated_child.wildcards.single) == 0 and
             MapSet.size(updated_child.wildcards.multi) == 0 do
          %{trie | children: Map.delete(trie.children, part)}
        else
          %{trie | children: Map.put(trie.children, part, updated_child)}
        end
    end
  end

  # Find subscribers
  defp do_find(trie, [], acc) do
    acc
    |> MapSet.union(trie.subscribers)
    |> MapSet.union(trie.wildcards.multi)
  end

  defp do_find(trie, [part | rest], acc) do
    acc = MapSet.union(acc, trie.wildcards.multi)
    acc = MapSet.union(acc, trie.wildcards.single)

    exact_match =
      if child = Map.get(trie.children, part) do
        do_find(child, rest, acc)
      else
        acc
      end

    MapSet.union(exact_match, acc)
  end
end
