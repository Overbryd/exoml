defmodule ExomlTest do
  use ExUnit.Case

  test "back and forth" do
    xml = "<tag foo=\"bar\">some text</tag>"
    assert xml == Exoml.encode(Exoml.decode(xml))
  end

  test "back and forth 2 attributes" do
    xml = "<tag foo=\"bar\" bar=\"foo\">some text</tag>"
    assert xml == Exoml.encode(Exoml.decode(xml))
  end

  test "virtual root node, never gonna give you up" do
    assert {:root, [], [{"tag", [], nil}, {"tag", [], nil}]} = Exoml.decode("<tag/><tag/>")
    assert {:root, [], ["\nfoo"]} = Exoml.decode("\nfoo")
    assert {:root, [], []} = Exoml.decode("")
  end

  test "tag without content" do
    assert {:root, [], [{"tag", [], []}]} = Exoml.decode("<tag></tag>")
    assert {:root, [], [{"tag", [], []}]} = Exoml.decode("<tag   ></tag>")
  end

  test "tag with content" do
    assert {:root, [], [{"tag", [], ["some freetext"]}]} = Exoml.decode("<tag>some freetext</tag>")
    assert {:root, [], [{"tag", [], ["\s\nsome freetext"]}]} = Exoml.decode("<tag>\s\nsome freetext</tag>")
  end

  test "self closing tag" do
    assert {:root, [], [{"tag", [], nil}]} = Exoml.decode("<tag/>")
    assert {:root, [], [{"tag", [], nil}]} = Exoml.decode("<tag   />")
  end

  test "virtual root node with text nodes" do
    assert {:root, [], ["\n     ", {"tag", [], nil}, "\n some freetext"]} = Exoml.decode("\n     <tag/>\n some freetext")
  end

  test "prolog" do
    prolog = {:prolog, [{"version", "1.0"}, {"encoding", "utf-8"}], nil}
    assert {:root, [], [^prolog]} = Exoml.decode("<?xml version=1.0 encoding=utf-8?>")
    assert {:root, [], [^prolog]} = Exoml.decode("<?XML version=1.0 encoding=utf-8 ?>")
    assert {:root, [], [^prolog]} = Exoml.decode("<?XmL version=1.0 encoding=utf-8 ?>")
  end

  test "doctype" do
    doctype = {:doctype, [" html"], nil}
    assert {:root, [], [^doctype]} = Exoml.decode("<!DOCTYPE html>")
    assert {:root, [], [^doctype]} = Exoml.decode("<!doctype html>")
    assert {:root, [], [^doctype]} = Exoml.decode("<!dOcTyPe html>")
    assert {:root, [], [{:doctype, [" html"], nil}, "\n", {"html", [], []}]} = Exoml.decode("<!DOCTYPE html>\n<html></html>")
    assert {:root, [], [{:doctype, [" html"], nil}, {"html", [{"lang", "en-US-x-Hixie"}], ["foobar"]}]} = Exoml.decode(~s'<!DOCTYPE html><html lang="en-US-x-Hixie">foobar</html>')
  end

  test "comments" do
    assert {:root, [], [{:comment, [], [" some comment "]}]} = Exoml.decode("<!-- some comment -->")
    assert {:root, [], [{:comment, [], ["some comment > <!"]}]} = Exoml.decode("<!--some comment > <!-->")
  end

  test "comment malformed" do
    assert {:root, [], ["<!-- some attempt to comment --!>"]} = Exoml.decode("<!-- some attempt to comment --!>")
  end

  test "cdata" do
    escaped = """
      <some><escaped><xml>
      foo
      </xml>
      </escaped>
      </some>
    """
    xml = "<tag><![CDATA[#{escaped}]]></tag>"
    assert {:root, [], [
      {"tag", [], [{:cdata, [], [^escaped]}]}
    ]} = Exoml.decode(xml)
    assert {:root, [], [
      {"ms", [], [{:cdata, [], ["x<y3"]}]}
    ]} = Exoml.decode("<ms><![CDATA[x<y3]]></ms>")
  end

  test "cdata malformed" do
    xml = "<tag><![CDATA[<xml>foo</xml></tag>"
    assert {:root, [], [
      {"tag", [], ["<![CDATA[", {"xml", [], ["foo"]}]}
    ]} = Exoml.decode(xml)
    assert {:root, [], [
      {"ms", [], [{:cdata, [], ["x<y3"]}, "]]>"]}
    ]} = Exoml.decode("<ms><![CDATA[x<y3]]>]]></ms>")
  end

  test "nested tags" do
    assert {:root, [], [{"outer", [], [{"inner", [], ["text"]}]}]} = Exoml.decode("<outer><inner>text</inner></outer>")
    assert {:root, [], [{"outer", [], ["   ", {"inner", [], ["text"]}]}]} = Exoml.decode("<outer>   <inner>text</inner></outer>")
    assert {:root, [], [{"outer", [], ["   ", {"inner", [], ["text"]}, "   "]}]} = Exoml.decode("<outer>   <inner>text</inner>   </outer>")
    assert {:root, [], [
      {"outer", [], [
        {"inner", [], [
          "text",
          {"span", [], ["more text"]}
        ]
      }]}
    ]} = Exoml.decode("<outer><inner>text<span>more text</span></inner></outer>")
  end

  test "tag with attributes" do
    assert {:root, [], [{"tag", [{"foo", "bar"}], nil}]} = Exoml.decode(~s'<tag foo="bar" />')
  end

  test "no attributes in tag" do
    assert [] = Exoml.Decoder.attrs("")
    assert [] = Exoml.Decoder.attrs("   ")
    assert [] = Exoml.Decoder.attrs("\s\n\r\f\t")
  end

  test "no attributes in self closing tag" do
    assert [] = Exoml.Decoder.attrs("/")
    assert [] = Exoml.Decoder.attrs("   /")
    assert [] = Exoml.Decoder.attrs("\s\n\r\f\t/")
  end

  test "single attributes" do
    assert [{"single", "single"}] = Exoml.Decoder.attrs("single /")
    assert [{"single", "single"}] = Exoml.Decoder.attrs("   single   /")
    assert ["single/"] = Exoml.Decoder.attrs("single/")
    assert [{"single", "single"}] = Exoml.Decoder.attrs("   single")
    assert [{"single", "single"}] = Exoml.Decoder.attrs("   single   ")
  end

  test "key value attributes" do
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key=value")
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key  =  value")
  end

  test "key value attributes with quotes" do
    assert [{"key", "value"}] = Exoml.Decoder.attrs(~s'key="value"')
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key='value'")
  end

  test "key value attributes with spaces before value" do
    assert [{"key", "value"}] = Exoml.Decoder.attrs(~s'key= "value"')
    assert [{"key", "value"}] = Exoml.Decoder.attrs(~s'key=\s\n\r\f\t"value"')
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key= 'value'")
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key=\s\n\r\f\t'value'")
    assert [{"key", "value"}] = Exoml.Decoder.attrs(~s'key = "value"')
    assert [{"key", "value"}] = Exoml.Decoder.attrs(~s'key\s\n\r\f\t=\s\n\r\f\t"value"')
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key = 'value'")
    assert [{"key", "value"}] = Exoml.Decoder.attrs("key\s\n\r\f\t=\s\n\r\f\t'value'")
  end

  test "key value multiple assignements" do
    assert [
      {"a", "1"},
      {"b", "2"},
      {"c", "3"},
      {"d", "d"},
      {"e", "5"}
    ] = Exoml.Decoder.attrs("a=1 b='2' c=\"3\" d e = 5 /")
  end

  test "key value broken equal assignements" do
    assert [{"src", ~s'alt="foo"'}] = Exoml.Decoder.attrs(~s' src= alt="foo" /')
    assert [{"src", ~s'alt="foo"/'}] = Exoml.Decoder.attrs(~s' src= alt="foo"/')
    assert ["src/", {"alt", "foo"}] = Exoml.Decoder.attrs(~s' src/ alt="foo" /')
  end

  test "key value unterminated quotes" do
    assert ["src='some"] = Exoml.Decoder.attrs("src='some")
    assert [~s'src="some'] = Exoml.Decoder.attrs(~s'src="some')
    assert ["src='some"] = Exoml.Decoder.attrs("src='some /")
    assert [~s'src="some'] = Exoml.Decoder.attrs(~s'src="some /')
    assert ["src='some/"] = Exoml.Decoder.attrs("src='some/")
    assert [~s'src="some/'] = Exoml.Decoder.attrs(~s'src="some/')
  end

  test "key value multiple assignements mixed with broken contents" do
    assert [
      "src/",
      {"alt", "just fine"}
    ] = Exoml.Decoder.attrs("src/ alt='just fine'")
    assert [
      {"a", "1"},
      "src/",
      {"b", "2"},
      {"c", "c"},
      {"d", "4"},
      "argshit/"
    ] = Exoml.Decoder.attrs(" a=1 src/ b='2' c d=\"4\" argshit/ /")
  end

  test "invalid closing tags" do
    assert {:root, [], ["</xml>"]} = Exoml.decode("</xml>")
    assert {:root, [], [{"tag", [], ["  </garble>", {"img", [{"src", "http://foobar.com"}], nil}, "some text"]}]} = Exoml.decode("<tag>  </garble><img src=http://foobar.com />some text")
    assert {:root, [], [{"tag", [], ["  </garble> gurble ", {"img", [{"src", "http://foobar.com"}], nil}, "some text"]}]} = Exoml.decode("<tag>  </garble> gurble <img src=http://foobar.com />some text")
  end

  test "full document with broken stuff" do
    html = """
      <?xml version=1.0 encoding=utf-8?>
      <!DOCTYPE html>
      <html>
      <body>

      </garble>
      <img src= alt="foo" />
      <img src= alt="foo"/>
      <img src/ alt="foo" />
      <img />
      <p>Open link in a new window or tab: <a href= target="_blank">Visit W3Schools!</a></p>

      </body>
      </html>
    """
    Exoml.decode(html)
  end
end

