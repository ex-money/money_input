defmodule MoneyInput.MixProject do
  use Mix.Project

  @version "0.2.2"
  @source_url "https://github.com/ex-money/money_input"

  def project do
    [
      app: :ex_money_input,
      version: @version,
      name: "Money.Input",
      source_url: @source_url,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: ~w(ecto gettext mix phoenix_html phoenix_live_view)a,
        flags: [
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Locale-aware money form input — <.money_input> and <.currency_picker> Phoenix HEEx " <>
      "components, an AutoNumeric-backed JS hook, and an Ecto changeset bridge."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: ~w(lib priv guides mix.exs README.md CHANGELOG.md LICENSE.md)
    ]
  end

  defp links do
    %{
      "GitHub" => @source_url,
      "Readme" => "#{@source_url}/blob/v#{@version}/README.md",
      "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "guides/integration.md",
        "guides/styling.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      formatters: ["html"],
      groups_for_modules: groups_for_modules(),
      # External-package references that ex_doc can't follow
      # because the host package isn't in this docs build.
      skip_code_autolink_to: [
        "Ecto.Changeset.t/0",
        "Supervisor.child_spec/0",
        "Localize.LanguageTag.t/0",
        "Money.t/0"
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp groups_for_modules do
    [
      Components: ~r/^Money\.Input\.Components(\.|$)/,
      "Headless API": [
        Money.Input.Cast,
        Money.Input.Validator,
        Money.Input.Currency,
        Money.Input.Changeset
      ],
      Exceptions: [
        Money.Input.NoNumberSymbolsError,
        Money.Input.ValidationError
      ]
    ]
  end

  defp deps do
    [
      {:ex_money, "~> 6.0"},
      {:localize, "~> 0.36"},
      {:phoenix_html, "~> 4.0", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:ecto, "~> 3.10", optional: true},
      {:gettext, "~> 1.0"},
      {:ex_doc, "~> 0.30", only: [:dev, :release], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ] ++ maybe_json_polyfill()
  end

  defp maybe_json_polyfill do
    if Code.ensure_loaded?(:json) do
      []
    else
      [{:json_polyfill, "~> 0.2 or ~> 1.0"}]
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
