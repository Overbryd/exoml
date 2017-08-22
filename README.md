# Exoml

A module to decode/encode xml into a tree structure.

## Examples

Handles well formed xml/html.

```elixir
Exoml.decode("<tag foo=bar>some text<self closing /></tag>")
{:root, [],
 [{"tag", [{"foo", "bar"}],
   ["some text", {"self", [{"closing", "closing"}], nil}]}]}
```

Handles bare strings.

```elixir
Exoml.decode("what, this is not xml")
{:root, [], ["what, this is not xml"]}

Exoml.decode("")
{:root, [], []}
```

Handles stuff that any browser would render.

```elixir
Exoml.decode("Well, it renders <b>in the browser</b>")
{:root, [], ["Well, it renders ", {"b", [], ["in the browser"]}]}
```

One can easily `decode/1` and `encode/1` without loosing too much of the original document.

```elixir
xml = ~s'<tag foo="bar">some text</tag>'
^xml = Exoml.encode(Exoml.decode(xml))
# => "<tag foo=\"bar\">some text</tag>"
```

## Performance

See `bench/` directory or run `mix bench` upon checkout.

Here are the results on a `MacBookPro11,5 i7 2.5GHz 16GB RAM`:

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exoml` to your list of dependencies in `mix.exs`:

```elixir
{:exoml, "~> 0.0.2"}
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exoml](https://hexdocs.pm/exoml).

