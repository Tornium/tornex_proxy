defmodule TornexProxyTest do
  use ExUnit.Case
  doctest TornexProxy

  test "greets the world" do
    assert TornexProxy.hello() == :world
  end
end
