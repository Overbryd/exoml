defmodule Exoml do
  @moduledoc """
  A module to decode/encode xml into a tree structure.

  The aim of this parser is to be able to represent any xml/html5 document as a tree-like structure,
  but be able to put it back together in a sane way.

  In comparison to other xml parsers, this one preserves 99.9% of the broken stuff.
  The goal is to be able to decode the typical broken html document, modify it, and encode it again,
  without loosing too much of its quirks.

  Currently the parser preserves whitespace between &lt;xml> nodes, so &lt;pre> or &lt;textarea> tags should be unaffected,
  by a `decode/1` into `encode/1`.

  The only part where the parser tidies up, is the `attr="part"` of a &lt;xml attr="part"> node.

  With well-formed XML, the parser does work really well.
  """

  @typep attrs() :: binary() | {binary(), binary()} | {binary()}
  @typep n_list() :: [] | [n()]
  @typep n() :: binary() | {binary(), attrs(), n_list()} | {binary(), attrs(), nil}

  @doc """
  Returns a tree representation from the given xml/html5 string.

  ## Examples

      iex> Exoml.decode("<tag foo=bar>some text<self closing /></tag>")
      {"tag", [{"foo", "bar"}], ["some text", {"self", [{"closing"}], nil}]}

      iex> Exoml.decode("what, this is not xml")
      {:root, [], ["what, this is not xml"]}

      iex> Exoml.decode("Well, it renders <b>in the browser</b>")
      {:root, [], ["Well, it renders ", {"b", [], ["in the browser"]}]}

  """
  @spec decode(binary()) :: node()
  def decode(bin) when is_binary(bin) do
    Exoml.Decoder.decode(bin)
  end

  @doc """
  Returns a string representation from the given xml tree

  Note: Exoml does not aim to perfectly preserve a decoded xml document. Just well enough.

  ## Examples

      iex> xml = ~s'<tag foo="bar">some text</tag>'
      iex> ^xml = Exoml.encode(Exoml.decode(xml))
      "<tag foo=\"bar\">some text</tag>"

  """
  @spec encode(n()) :: binary()
  def encode(tree) when is_tuple(tree) do
    Exoml.Encoder.encode(tree)
  end
end

