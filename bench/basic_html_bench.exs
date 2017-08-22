defmodule BasicHtmlBench do
  use Benchfella

  @html File.read!("bench/w3c_html5.html")
  @decoded Exoml.decode(@html)

  bench "decode" do
    Exoml.decode(@html)
  end

  bench "encode" do
    Exoml.encode(@decoded)
  end
end

