defmodule BeamRED.Utils do
  require Logger

  @type id :: String.t()

  @doc """
  Generates a random binary id.
  """
  @spec random_id() :: id()
  def random_id() do
    :crypto.strong_rand_bytes(10) |> Base.encode32(case: :lower)
  end

  @doc """
  Generates a random long binary id.
  """
  @spec random_long_id() :: id()
  def random_long_id() do
    :crypto.strong_rand_bytes(20) |> Base.encode32(case: :lower)
  end

  @doc """
  Checks if the given module exports the given function.

  Loads the module if not loaded.
  """
  @spec has_function?(module(), atom(), arity()) :: boolean()
  def has_function?(module, function, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  @doc """
  """
  @spec diff(map(), map()) :: %{added: map(), removed: map(), changed: map()}
  def diff(old, new) do
    old_keys = Map.keys(old)
    new_keys = Map.keys(new)

    # Added keys: present in new but not in old
    added = Map.drop(new, old_keys)

    # Removed keys: present in old but not in new
    removed = Map.drop(old, new_keys)

    # Changed keys: keys in both maps with different values
    changed =
      Map.intersect(old, new, fn _k, v1, v2 ->
        v1_hash = :erlang.phash2(v1)
        v2_hash = :erlang.phash2(v2)

        if v1_hash == v2_hash do
          false
        else
          v2
        end
      end)
      |> Map.filter(fn {_k, v} -> v end)

    %{added: added, removed: removed, changed: changed}
  end
end
