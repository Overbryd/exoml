defmodule Exoml.Decoder do
  import Kernel, except: [node: 0, node: 1]

  @ascii_whitespace ["\t", "\n", "\f", "\r", "\s"]
  @ascii_control Enum.map(0x007f..0x009f, &(<<&1>>))
  @attr_name_stop @ascii_whitespace ++ @ascii_control ++ [~s' ', "'", ">", "/", "="]
  @attr_value_quote ["'", ~s'"']
  @escape_sequences %{
    "&amp;" => "&",
    "&lt;" => "<",
    "&gt;" => ">",
    "&quot;" => "\"",
    "&apos;" => "'",
  }

  def escape_sequences(), do: @escape_sequences

  def decode(bin) when is_binary(bin) do
    root(bin, [])
  end

  defp root("", children), do: {:root, [], children}

  defp root(bin, children) do
    {nodes, trail} = content(bin, :root, "")
    root(trail, children ++ nodes)
  end

  # prolog

  defp content(<<"<?", xml :: binary-size(3), trail :: binary>>, :root, lead) do
    if String.upcase(xml) == "XML" do
      prolog(xml, trail, lead)
    else
      content(trail, :root, lead <> "<?" <> xml)
    end
  end

  # <!DOCTYPE

  defp content(<<"<!", dta::binary-size(2), dtb :: binary-size(5), trail :: binary>>, :root, lead)
  when dta != "--"
  do
    dt = dta <> dtb
    if String.upcase(dt) == "DOCTYPE" do
      doctype(dt, trail, lead)
    else
      content(trail, :root, lead <> "<!" <> dt)
    end
  end

  # <![CDATA[

  defp content(<<"<![CDATA[", trail :: binary>>, tag, lead) do
    case String.split(trail, "]]>", parts: 2) do
      [data, trail] ->
        cdata_node = {:cdata, [], [data]}
        {trailing_nodes, rest} = content(trail, tag, "")
        nodes = if lead == "" do
          [cdata_node | trailing_nodes]
        else
          [lead, cdata_node | trailing_nodes]
        end
        {nodes, rest}
      [trail] ->
        content(trail, tag, lead <> "<![CDATA[")
    end
  end

  defp content(<<"</", bin :: binary>>, :root, lead) do
    content(bin, :root, lead <> "</")
  end

  defp content(<<"</", bin :: binary>>, tag, lead) do
    len = byte_size(tag)
    with <<^tag :: binary-size(len), rest :: binary>> <- bin,
      <<">", trail :: binary>> <- String.trim_leading(rest) do
      if lead == "" do
        {[], trail}
      else
        {[lead], trail}
      end
    else
      trail ->
        content(trail, tag, lead <> "</")
    end
  end

  # comment

  defp content(<<"<!--"::binary, _ :: binary>> = bin, tag, lead) do
    {node, trail} = comment(bin)
    {contents, trail} = content(trail, tag, "")
    children = if lead == "" do
      [node | contents]
    else
      [lead, node | contents]
    end
    {children, trail}
  end

  # node

  defp content(<<"<", _ :: binary>> = bin, tag, lead) do
    {node, trail} = node(bin)
    {contents, trail} = content(trail, tag, "")
    children = if lead == "" do
      [node | contents]
    else
      [lead, node | contents]
    end
    {children, trail}
  end

  for {sequence, value} <- @escape_sequences do
    defp content(<<unquote(sequence), bin :: binary>>, tag, acc)
    when is_binary(tag) and tag != ""
    do
      content(bin, tag, acc <> <<unquote(value)::utf8>>)
    end
  end

  for size <- 1..6 do
    defp content(<<"&#x", hex::binary-size(unquote(size)), ";", bin :: binary>>, tag, acc)
    when is_binary(tag), do: content_hexadecimal_character_reference(hex, bin, tag, acc)
  end

  for size <- 1..8 do
    defp content(<<"&#", decimal::binary-size(unquote(size)), ";", bin :: binary>>, tag, acc)
    when is_binary(tag), do: content_decimal_character_reference(decimal, bin, tag, acc)
  end

  defp content(<<lead :: utf8, bin :: binary>>, tag, acc) do
    content(bin, tag, acc <> <<lead::utf8>>)
  end

  defp content("", _tag, lead) do
    if lead == "" do
      {[], ""}
    else
      {[lead], ""}
    end
  end

  defp content_decimal_character_reference(decimal, bin, tag, acc) when is_binary(decimal) do
    case Integer.parse(decimal, 10) do
      {decimal, ""} ->
        content(bin, tag, acc <> <<decimal::utf8>>)
      _ ->
        content(bin, tag, acc <> "&##{decimal};")
    end
  end

  defp content_hexadecimal_character_reference(hex, bin, tag, acc) do
    case Integer.parse(hex, 16) do
      {decimal, ""} ->
        content(bin, tag, acc <> <<decimal::utf8>>)
      _ ->
        content(bin, tag, acc <> "&#x#{hex};")
    end
  end

  defp doctype(dt, trail, lead) do
    case String.split(trail, ">", parts: 2) do
      [head, trail] ->
        node = {:doctype, [head], nil}
        {[node], trail}
      [trail] ->
        content("", "", lead <> "<!" <> dt <> trail)
    end
  end

  defp prolog(xml, trail, lead) do
    case String.split(trail, "?>", parts: 2) do
      [head, trail] ->
        node = {:prolog, attrs(head), nil}
        {[node], trail}
      [trail] ->
        content("", "", lead <> "<?" <> xml <> trail)
    end
  end

  defp comment(<<"<!--", bin :: binary>>) do
    case String.split(bin, "-->", parts: 2) do
      # closing comment
      [body, trail] ->
        node = {:comment, [], [body]}
        {node, trail}
      # unclosed comment
      [trail] ->
        {"<!--#{trail}", ""}
    end
  end

  defp node(<<"<", bin :: binary>>) do
    case String.split(bin, ">", parts: 2) do
      [header, trail] ->
        len = byte_size(header) - 1
        case header do
          # self closing tag
          <<header :: binary-size(len), "/">> ->
            {tag, attrs} = tag(header)
            {{tag, attrs, nil}, trail}
          # open tag with children
          header ->
            {tag, attrs} = tag(header)
            {content, rest} = content(trail, tag, "")
            {{tag, attrs, content}, rest}
        end
      [trail] ->
        {"<#{bin}", ""}
    end
  end

  def tag(bin) do
    {tag, trail} = tag(bin, "")
    attrs = attrs(trail)
    {tag, attrs}
  end

  defp tag(<<ws :: utf8, _ :: binary>> = bin, acc) when <<ws::utf8>> in @ascii_whitespace do
    {acc, bin}
  end

  defp tag("/", acc) do
    {acc, ""}
  end

  defp tag("", acc) do
    {acc, ""}
  end

  defp tag(<<part :: utf8, trail :: binary>>, acc) do
    tag(trail, acc <> <<part::utf8>>)
  end

  def attrs(bin) do
    attrs(bin, [])
  end

  # strip whitespace before attribute name
  defp attrs(<<ws :: utf8, trail :: binary>>, acc) when <<ws::utf8>> in @ascii_whitespace do
    attrs(trail, acc)
  end

  # return on stop character
  defp attrs(<<stop :: utf8>>, acc) when <<stop::utf8>> in @attr_name_stop, do: attrs("", acc)

  # return on empty head
  defp attrs("", acc), do: Enum.reverse(acc)

  # pass to attr name
  defp attrs(<<_part :: utf8, _ :: binary>> = bin, acc) do
    attr_name(bin, "", acc)
  end

  # name

  defp attr_name(" /", name, acc) do
    attr_value("", name, nil, acc)
  end

  defp attr_name(<<"/", trail :: binary>>, name, acc) do
    attrs(trail, ["#{name}/" | acc])
  end

  defp attr_name(<<ws :: utf8, trail :: binary>>, "", acc) when <<ws::utf8>> in @ascii_whitespace do
    attr_name(trail, "", acc)
  end

  defp attr_name(<<stop :: utf8, _ :: binary>> = bin, name, acc) when <<stop::utf8>> in @attr_name_stop do
    attr_value(bin, name, nil, acc)
  end

  defp attr_name(<<part :: utf8, trail :: binary>>, name, acc) do
    attr_name(trail, name <> <<part::utf8>>, acc)
  end

  defp attr_name("", name, acc) do
    attr_value("", name, nil, acc)
  end

  # value

  # strip whitespace before attribute value
  defp attr_value(<<ws :: utf8, trail :: binary>>, name, nil, acc) when <<ws::utf8>> in @ascii_whitespace do
    attr_value(trail, name, nil, acc)
  end

  # strip whitespace before attribute value
  defp attr_value(<<ws :: utf8, trail :: binary>>, name, "", acc) when <<ws::utf8>> in @ascii_whitespace do
    attr_value(trail, name, "", acc)
  end

  # stop on whitespace for unquoted attribute values
  defp attr_value(<<ws :: utf8, trail :: binary>>, name, value, acc) when <<ws::utf8>> in @ascii_whitespace do
    attrs(trail, [{name, value} | acc])
  end

  defp attr_value(<<"=", trail :: binary>>, name, nil, acc) do
    attr_value(trail, name, "", acc)
  end

  defp attr_value(<<qt :: utf8, trail :: binary>>, name, "", acc) when <<qt::utf8>> in @attr_value_quote do
    case String.split(trail, <<qt::utf8>>, parts: 2) do
      # quote terminates
      [value, trail] ->
        attrs(trail, [{name, value} | acc])
      # unterminated quote
      [trail] ->
        # attrs("", [{name, trail} | acc])
        attrs("", ["#{name}=#{<<qt::utf8>>}#{String.trim_trailing(trail, " /")}"])
    end
  end

  defp attr_value(" /", name, value, acc) do
    attr_value("", name, value, acc)
  end

  defp attr_value(trail, name, nil, acc) do
    attrs(trail, [{name, name} | acc])
  end

  defp attr_value(<<part :: utf8, trail :: binary>>, name, value, acc) do
    attr_value(trail, name, "#{value}#{<<part::utf8>>}", acc)
  end

  defp attr_value("", "", "", acc) do
    acc
  end

  defp attr_value("", name, value, acc) do
    if is_nil(value) do
      # empty single attribute
      [{name, name} | acc]
    else
      # key-value attribute
      [{name, value} | acc]
    end |> Enum.reverse
  end

end

