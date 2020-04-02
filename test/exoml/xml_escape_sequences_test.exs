defmodule Exoml.XMLEscapeSequencesTest do
  use ExUnit.Case

  test "text is text outside of tags" do
    not_xml = "&quot;"
    assert {:root, [], [not_xml]} == Exoml.decode(not_xml)
    assert {:root, [], [{"text", [], ["hello"]}, not_xml]} == Exoml.decode("<text>hello</text>#{not_xml}")
  end

  test "named entities inside attributes" do
    xml = "<itunes:image href=\"&amp;size=Large\"></itunes:image>"
    assert {:root, [], [
      {"itunes:image", [{"href", "&size=Large"}], []}
    ]} == Exoml.decode(xml)
  end

  test "text is text inside of <![CDATA[ ... ]]" do
    cdata = "&quot;"
    assert {
      :root, [], [
        {"text", [], [
          {:cdata, [], [cdata]}
        ]}
    ]} == Exoml.decode("<text><![CDATA[#{cdata}]]></text>")
  end

  test "named entities" do
    for {name, utf8} <- Exoml.Entities.entities() do
      assert {:root, [], [{"text", [], [utf8]}]} == Exoml.decode("<text>&#{name};</text>")
    end
  end

  test "decimal character references" do
    for i <- 1..0xfff do
      codepoint = to_string(i)
      assert {:root, _, [{"text", _, [<<i::utf8>>]}]} = Exoml.decode("<text>&##{codepoint};</text>")
      assert {:root, _, [{"text", _, [<<i::utf8>>]}]} = Exoml.decode("<text>&##{String.pad_leading(codepoint, 8, "0")};</text>")
    end
  end

  test "hexadecimal character references" do
    for i <- 1..0xfff do
      hexcode = Integer.to_string(i, 16)
      assert {:root, _, [{"text", _, [<<i::utf8>>]}]} = Exoml.decode("<text>&#x#{hexcode};</text>")
      mix_code = String.split(hexcode, "")
                 |> Enum.map(fn c ->
                   if :rand.uniform >= 0.5, do: String.upcase(c), else: String.downcase(c)
                 end)
      assert {:root, _, [{"text", _, [<<i::utf8>>]}]} = Exoml.decode("<text>&#x#{mix_code};</text>")
    end
  end
end
