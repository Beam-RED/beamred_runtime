defmodule NodeEx.MQTT.Topics do
  @type published_topic() :: [String.t()]
  @type subscribed_topic() :: [String.t()]

  @spec parse_published_topic(String.t()) :: {:ok, published_topic()} | :error
  def parse_published_topic(""), do: :error

  def parse_published_topic(topic) when is_binary(topic) do
    result = String.split(topic, "/")

    if result |> Enum.all?(&valid_published_segment?/1) do
      {:ok, result}
    else
      :error
    end
  end

  defp valid_published_segment?(segment) do
    !(String.contains?(segment, "+") || String.contains?(segment, "#"))
  end

  @spec parse_subscribed_topic(String.t()) :: {:ok, subscribed_topic()} | :error
  def parse_subscribed_topic(""), do: :error

  def parse_subscribed_topic(topic) do
    result = String.split(topic, "/")
    {beginning, [last]} = Enum.split(result, Enum.count(result) - 1)

    if Enum.all?(beginning, fn s -> valid_subscribed_segment?(s, false) end) &&
         valid_subscribed_segment?(last, true) do
      {:ok, result}
    else
      :error
    end
  end

  defp valid_subscribed_segment?("+", _), do: true
  defp valid_subscribed_segment?("#", true), do: true

  defp valid_subscribed_segment?(segment, _) do
    !(String.contains?(segment, "+") || String.contains?(segment, "#"))
  end

  @spec matches?(published_topic(), subscribed_topic()) :: boolean()
  def matches?([], []) do
    true
  end

  def matches?([x | rest_p], [x | rest_s]) do
    matches?(rest_p, rest_s)
  end

  def matches?([_ | rest_p], ["+" | rest_s]) do
    matches?(rest_p, rest_s)
  end

  def matches?(_, ["#"]) do
    true
  end

  def matches?(_, _) do
    false
  end
end
