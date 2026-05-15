defmodule MoneyInput.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :money_input,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Locale-aware number and money form input — headless parser/formatter/validator " <>
      "with a Plug-based visualizer for local development."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      files: ~w(lib priv mix.exs README.md)
    ]
  end

  defp deps do
    [
      {:ex_money, "~> 6.0", path: "../money"},
      {:localize, "~> 0.27", path: "../../localize/localize", override: true},
      {:phoenix_html, "~> 4.0", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:ecto, "~> 3.10", optional: true},
      {:gettext, "~> 1.0", optional: true},
      {:plug, "~> 1.15", optional: true},
      {:bandit, "~> 1.5", optional: true}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
