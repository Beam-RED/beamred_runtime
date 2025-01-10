defmodule NodeExRuntimeTest do
  use ExUnit.Case
  doctest NodeExRuntime

  test "greets the world" do
    assert NodeExRuntime.hello() == :world
  end
end
