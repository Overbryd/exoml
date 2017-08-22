defmodule Exoml do

  @typep attrs() :: binary() | {binary(), binary()} | {binary()}
  @typep n_list() :: [] | [n()]
  @typep n() :: binary() | {binary(), attrs(), n_list()} | {binary(), attrs(), nil}

  @doc """
    Returns a tree representation from the given xml/html5 string.

    ## Example
    iex> Exoml.decode("<tag foo=bar>some text<self closing /></tag>")
    {"tag", [{"foo", "bar"}], ["some text", {"self", [{"closing"}], nil}]}
  """
  @spec decode(binary()) :: node()
  def decode(bin) when is_binary(bin) do
    Exoml.Decoder.decode(bin)
  end

  @doc """
    Returns a string representation from the given xml tree

    Note: Exoml does not aim to perfectly preserve a decoded xml document.

    ## Example
    iex> xml = ~s'<tag foo="bar">some text</tag>'
    iex> xml = Exoml.encode(Exoml.decode(xml))
    ~s'<tag foo="bar">some text</tag>'
  """
  @spec encode(n()) :: binary()
  def encode(tree) when is_tuple(tree) do
    Exoml.Encoder.encode(tree)
  end
end

