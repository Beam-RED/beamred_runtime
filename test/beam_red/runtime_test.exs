defmodule BeamRED.RuntimeTest do
  use ExUnit.Case
  doctest BeamRED.Runtime

  test "greets the world" do
    assert BeamRED.Runtime.hello() == :world
  end
end
