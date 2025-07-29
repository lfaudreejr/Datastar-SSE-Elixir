defmodule DataStarSSE.MixProject do
  use Mix.Project

  def project do
    [
      app: :datastar_sse,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      deps: deps(),
      name: "Datastar-SSE",
      source_url: "https://github.com/lfaudreejr/Datastar-SSE-Elixir"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Elixir SSE Helpers for DataStar (https://data-star.dev) - A framework for building reactive web applications using Server-Sent Events and hypermedia."
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:plug, "~>1.18.1"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.0", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/lfaudreejr/Datastar-SSE-Elixir"},
      exclude_patterns: ["lib/scripts"]
    ]
  end
end
