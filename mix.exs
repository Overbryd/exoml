defmodule Exoml.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exoml,
      version: "0.0.3",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: "A module to decode/encode xml into a tree structure",
      package: [
        maintainers: ["Lukas Rieder"],
        licenses: ["MIT"],
        links: %{"Github" => "https://github.com/Overbryd/exoml"}
      ],
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:benchfella, "~> 0.3.0", only: :dev}
    ]
  end
end
