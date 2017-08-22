defmodule ExomlTest do
  use ExUnit.Case

  test "back and forth" do
    xml = "<tag foo=\"bar\">some text</tag>"
    assert xml == Exoml.encode(Exoml.decode(xml))
  end

  test "virtual root node" do
    assert {:root, [], [{"tag", [], nil}, {"tag", [], nil}]} = Exoml.decode("<tag/><tag/>")
    assert {:root, [], [{"tag", [], nil}, "\n    ", {"tag", [], nil}]} = Exoml.decode("<tag/>\n    <tag/>")
  end

  test "self closing tag" do
    assert {"tag", [], nil} = Exoml.decode("<tag/>")
  end

  test "virtual root node with text nodes" do
    assert {:root, [], ["\n     ", {"tag", [], nil}, "\n some freetext"]} = Exoml.decode("\n     <tag/>\n some freetext")
  end

  test "prolog" do
    assert {:prolog, [{"version", "1.0"}, {"encoding", "utf-8"}], nil} = Exoml.decode("<?xml version=1.0 encoding=utf-8?>")
    assert {:prolog, [{"version", "1.0"}, {"encoding", "utf-8"}], nil} = Exoml.decode("<?XML version=1.0 encoding=utf-8 ?>")
    assert {:prolog, [{"version", "1.0"}, {"encoding", "utf-8"}], nil} = Exoml.decode("<?XmL version=1.0 encoding=utf-8 ?>")
  end

  test "doctype" do
    assert {:doctype, [" html"], nil} = Exoml.decode("<!DOCTYPE html>")
    assert {:doctype, [" html"], nil} = Exoml.decode("<!doctype html>")
    assert {:doctype, [" html"], nil} = Exoml.decode("<!dOcTyPe html>")
    assert {:root, [], [{:doctype, [" html"], nil}, "\n", {"html", [], []}]} = Exoml.decode("<!DOCTYPE html>\n<html></html>")
  end

  test "comments" do
    assert {:root, [], ["<!-- some comment -->"]} = Exoml.decode("<!-- some comment -->")
    assert {:root, [], ["<!--some comment > <!-->"]} = Exoml.decode("<!--some comment > <!-->")
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
    assert {"tag", [], [
      {:cdata, [], [^escaped]}
    ]} = Exoml.decode(xml)
    assert {"ms", [], [{:cdata, [], ["x<y3"]}]} = Exoml.decode("<ms><![CDATA[x<y3]]></ms>")
  end

  test "cdata malformed" do
    xml = "<tag><![CDATA[<xml>foo</xml></tag>"
    assert {"tag", [], [
      "<![CDATA[",
      {"xml", [], ["foo"]}
    ]} = Exoml.decode(xml)
    assert {"ms", [], [{:cdata, [], ["x<y3"]}, "]]>"]} = Exoml.decode("<ms><![CDATA[x<y3]]>]]></ms>")
  end

  test "extract tag contents" do
    assert {"tag", [], ["text"]} = Exoml.decode("<tag>text</tag>")
    assert {"tag", [], ["text   "]} = Exoml.decode("<tag>text   </tag>")
    assert {"tag", [], ["   text   "]} = Exoml.decode("<tag>   text   </tag>")
  end

  test "nested tags" do
    assert {"outer", [], [{"inner", [], ["text"]}]} = Exoml.decode("<outer><inner>text</inner></outer>")
    assert {"outer", [], ["   ", {"inner", [], ["text"]}]} = Exoml.decode("<outer>   <inner>text</inner></outer>")
    assert {"outer", [], ["   ", {"inner", [], ["text"]}, "   "]} = Exoml.decode("<outer>   <inner>text</inner>   </outer>")
    assert {"outer", [], [
      {"inner", [], [
        "text",
        {"span", [], ["more text"]}
      ]
    }]} = Exoml.decode("<outer><inner>text<span>more text</span></inner></outer>")
  end

  test "tag attributes" do
    assert {"tag", [{"foo", "bar"}], nil} = Exoml.decode(~s'<tag foo="bar" />')
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
    assert [{"single"}] = Exoml.Decoder.attrs("single /")
    assert [{"single"}] = Exoml.Decoder.attrs("   single   /")
    assert ["single/"] = Exoml.Decoder.attrs("single/")
    assert [{"single"}] = Exoml.Decoder.attrs("   single")
    assert [{"single"}] = Exoml.Decoder.attrs("   single   ")
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
      {"d"},
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
      {"c"},
      {"d", "4"},
      "argshit/"
    ] = Exoml.Decoder.attrs(" a=1 src/ b='2' c d=\"4\" argshit/ /")
  end

  test "invalid closing tags" do
    assert {:root, [], ["</xml>"]} = Exoml.decode("</xml>")
    assert {"tag", [], ["  </garble>", {"img", [{"src", "http://foobar.com"}], nil}, "some text"]} = Exoml.decode("<tag>  </garble><img src=http://foobar.com />some text")
    assert {"tag", [], ["  </garble> gurble ", {"img", [{"src", "http://foobar.com"}], nil}, "some text"]} = Exoml.decode("<tag>  </garble> gurble <img src=http://foobar.com />some text")
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
    IO.inspect Exoml.decode(html)
  end
end
