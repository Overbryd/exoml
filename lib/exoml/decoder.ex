defmodule Exoml.Decoder do
  import Kernel, except: [node: 0, node: 1]

  @ascii_whitespace ["\t", "\n", "\f", "\r", "\s"]
  @ascii_control Enum.map(0x007f..0x009f, &(<<&1>>))
  @attr_name_stop @ascii_whitespace ++ @ascii_control ++ [~s' ', "'", ">", "/", "="]
  @attr_value_quote ["'", ~s'"']

  def decode(bin) when is_binary(bin) do
    dom(bin)
  end

  defp dom(bin) when is_binary(bin) do
    dom(bin, [])
  end

  defp dom("", children), do: {:root, [], children}

  defp dom(bin, children) do
    case content(bin, "", "") do
      # single text node, wrap in :root
      {[node], ""} when is_binary(node) ->
        dom("", [node])
      # tree node
      {[node], ""} when is_tuple(node) ->
        node
      # continue parsing
      {nodes, trail} ->
        dom(trail, children ++ nodes)
    end
  end

  # comment

  defp content(<<"<!--", bin :: binary>>, "", lead) do
    nodes = if lead == "" do
      []
    else
      [lead]
    end
    case String.split(bin, "-->", parts: 2) do
      # closing comment
      [body, trail] ->
        {["<!--#{body}-->" | nodes], trail}
      # unclosed comment
      [trail] ->
        {["<!--#{trail}" | nodes], ""}
    end
  end

  # prolog

  defp content(<<"<?", xml :: binary-size(3), trail :: binary>>, "", lead) do
    if String.upcase(xml) == "XML" do
      prolog(xml, trail, lead)
    else
      content(trail, "", lead <> "<?" <> xml)
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

  # <!DOCTYPE

  defp content(<<"<!", dt :: binary-size(7), trail :: binary>>, "", lead) do
    if String.upcase(dt) == "DOCTYPE" do
      doctype(dt, trail, lead)
    else
      content(trail, "", lead <> "<!" <> dt)
    end
  end

  defp doctype(dt, trail, lead) do
    nodes = if lead == "" do
      []
    else
      [lead]
    end
    case String.split(trail, ">", parts: 2) do
      [head, trail] ->
        node = {:doctype, [head], nil}
        {[node], trail}
      [trail] ->
        content("", "", lead <> "<!" <> dt <> trail)
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

  defp content(<<"</", bin :: binary>>, "", lead) do
    content(bin, "", lead <> "</")
  end

  defp content(<<"</", bin :: binary>>, tag, lead) do
    len = String.length(tag)
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

  defp content(<<lead :: binary-size(1), bin :: binary>>, tag, acc) do
    content(bin, tag, acc <> lead)
  end

  defp content("", _tag, lead) do
    if lead == "" do
      {[], ""}
    else
      {[lead], ""}
    end
  end

  defp node(<<"<", bin :: binary>>) do
    [header, trail] = String.split(bin, ">", parts: 2)
    len = String.length(header) - 1
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
  end

  def tag(bin) do
    {tag, trail} = tag(bin, "")
    attrs = attrs(trail)
    {tag, attrs}
  end

  defp tag(<<ws :: binary-size(1), _ :: binary>> = bin, acc) when ws in @ascii_whitespace do
    {acc, bin}
  end

  defp tag("/", acc) do
    {acc, ""}
  end

  defp tag("", acc) do
    {acc, ""}
  end

  defp tag(<<part :: binary-size(1), trail :: binary>>, acc) do
    tag(trail, acc <> part)
  end

  def attrs(bin) do
    attrs(bin, [])
  end

  # strip whitespace before attribute name
  defp attrs(<<ws :: binary-size(1), trail :: binary>>, acc) when ws in @ascii_whitespace do
    attrs(trail, acc)
  end

  # return on stop character
  defp attrs(<<stop :: binary-size(1)>>, acc) when stop in @attr_name_stop, do: attrs("", acc)

  # return on empty head
  defp attrs("", acc), do: Enum.reverse(acc)

  # pass to attr name
  defp attrs(<<_part :: binary-size(1), _ :: binary>> = bin, acc) do
    attr_name(bin, "", acc)
  end

  # name

  defp attr_name(" /", name, acc) do
    attr_value("", name, nil, acc)
  end

  defp attr_name(<<"/", trail :: binary>>, name, acc) do
    attrs(trail, ["#{name}/" | acc])
  end

  defp attr_name(<<ws :: binary-size(1), trail :: binary>>, "", acc) when ws in @ascii_whitespace do
    attr_name(trail, "", acc)
  end

  defp attr_name(<<stop :: binary-size(1), _ :: binary>> = bin, name, acc) when stop in @attr_name_stop do
    attr_value(bin, name, nil, acc)
  end

  defp attr_name(<<part :: binary-size(1), trail :: binary>>, name, acc) do
    attr_name(trail, "#{name}#{part}", acc)
  end

  defp attr_name("", name, acc) do
    attr_value("", name, nil, acc)
  end

  # value

  # strip whitespace before attribute value
  defp attr_value(<<ws :: binary-size(1), trail :: binary>>, name, nil, acc) when ws in @ascii_whitespace do
    attr_value(trail, name, nil, acc)
  end

  # strip whitespace before attribute value
  defp attr_value(<<ws :: binary-size(1), trail :: binary>>, name, "", acc) when ws in @ascii_whitespace do
    attr_value(trail, name, "", acc)
  end

  defp attr_value(<<ws :: binary-size(1), trail :: binary>>, name, value, acc) when ws in @ascii_whitespace do
    attrs(trail, [{name, value} | acc])
  end

  defp attr_value(<<"=", trail :: binary>>, name, nil, acc) do
    attr_value(trail, name, "", acc)
  end

  defp attr_value(<<qt :: binary-size(1), trail :: binary>>, name, "", acc) when qt in @attr_value_quote do
    case String.split(trail, qt, parts: 2) do
      # quote terminates
      [value, trail] ->
        attrs(trail, [{name, value} | acc])
      # unterminated quote
      [trail] ->
        attrs("", ["#{name}=#{qt}#{String.trim_trailing(trail, " /")}"])
    end
  end

  defp attr_value(" /", name, value, acc) do
    attr_value("", name, value, acc)
  end

  defp attr_value(trail, name, nil, acc) do
    attrs(trail, [{name} | acc])
  end

  defp attr_value(<<part :: binary-size(1), trail :: binary>>, name, value, acc) do
    attr_value(trail, name, "#{value}#{part}", acc)
  end

  defp attr_value("", name, value, acc) do
    if is_nil(value) do
      # empty single attribute
      [{name} | acc]
    else
      # key-value attribute
      [{name, value} | acc]
    end |> Enum.reverse
  end


end
