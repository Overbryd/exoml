defmodule Exoml.Encoder do

  def encode(tree) when is_tuple(tree) do
    encode(tree, "")
  end

  defp encode({:root, _, children}, acc) do
    encode(children, acc)
  end

  defp encode(bin, acc) when is_binary(bin) do
    bin <> acc
  end

  defp encode([node | tl], acc) do
    encode(node, encode(tl, acc))
  end

  defp encode([], acc), do: acc

  defp encode({:prolog, attrs, nil}, acc) do
    "<?xml " <> encode_attrs(attrs) <> " ?>" <> acc
  end

  defp encode({:doctype, attrs, nil}, acc) do
    "<!DOCTYPE" <> encode_attrs(attrs) <> " !>" <> acc
  end

  defp encode({tag, [], nil}, acc) do
    "<#{tag}/>" <> acc
  end

  defp encode({tag, attrs, nil}, acc) do
    "<#{tag} #{encode_attrs(attrs)} />" <> acc
  end

  defp encode({tag, [], children}, acc) do
    "<#{tag}>" <> encode(children, "") <> "</#{tag}>" <> acc
  end

  defp encode({tag, attrs, children}, acc) do
    "<" <> tag <> " " <> encode_attrs(attrs) <> ">" <> encode(children, "") <> "</#{tag}>" <> acc
  end

  defp encode_attrs(attrs) do
    encode_attrs(attrs, "")
  end

  defp encode_attrs([]), do: ""

  defp encode_attrs([attr | tl], "") do
    encode_attr(attr) <> encode_attrs(tl)
  end

  defp encode_attrs([attr | tl], acc) do
    trail = encode_attr(attr)
    if acc == "" do
      encode_attrs(tl, trail)
    else
      encode_attrs(tl, acc <> " " <> trail)
    end
  end

  defp encode_attrs([], acc), do: acc

  defp encode_attr({single}), do: single

  defp encode_attr({name, value}) do
    qt = cond do
      Regex.match?(~r/"/, value) -> "'"
      Regex.match?(~r/'/, value) -> ~s'"'
      true -> ~s'"'
    end
    "#{name}=#{qt}#{value}#{qt}"
  end

  defp encode_attr(bin), do: bin

end

