# TornexProxy
An Elixir library providing a plugable or installable proxy for the [Torn API](https://api.torn.com) (both version one and [version two](https://www.torn.com/swagger/index.html)). The library is built upon the [`tornex`](https://hex.pm/packages/tornex) and the [`torngen_elixir_client`](https://hex.pm/packages/torngen_elixir_client) libraries and provides the following features:
- Multi-node support
- IP ratelimiting
- Combination of similar queries

## Installation
If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tornex_proxy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tornex_proxy, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tornex_proxy>.
