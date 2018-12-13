defmodule PolicyWonk.Mixfile do
  use Mix.Project

  @version "1.0.0"
  @github "https://github.com/boydm/policy_wonk"
  @tutorial "https://medium.com/@boydm/policy-wonk-the-tutorial-6d2b6e435c46#.dz7utkmgb"

  def project do
    [
      app: :policy_wonk,
      version: @version,
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        contributors: ["Boyd Multerer"],
        maintainers: ["Boyd Multerer"],
        licenses: ["MIT"],
        links: %{github: @github, tutorial: @tutorial}
      ],
      name: "policy_wonk",
      source_url: @github,
      docs: docs(),
      description: """
      Plug based authorization and resource loading.
      Aimed at Phoenix, but depends only on Plug.
      MIT license
      Updated to compile clean with Elixir 1.4
      """
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:plug, "~> 1.1"},

      # Docs dependencies
      {:ex_doc, ">= 0.0.0", only: [:dev, :docs]},
      {:inch_ex, ">= 0.0.0", only: [:dev, :docs]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      source_ref: "v#{@version}",
      main: "PolicyWonk"
    ]
  end
end
