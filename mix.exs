defmodule FrancisPages.MixProject do
  use Mix.Project

  def project do
    [
      app: :francis_pages,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "File-based pages for Francis routers",
      source_url: "https://github.com/andyl/francis_pages",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:francis, "~> 0.4"},
      {:mdex, "~> 0.14"},
      {:yaml_elixir, "~> 2.11"}
    ]
  end
end
