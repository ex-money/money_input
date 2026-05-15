defmodule Money.Input do
  @moduledoc """
  Locale-aware number and money form input.

  This package ships three layers:

  1. **Headless** — `Money.Input.Parser`, `Money.Input.Formatter`,
     `Money.Input.Validator`, `Money.Input.Locale`. Pure Elixir,
     no Phoenix dependency. Usable from JSON APIs or non-LiveView
     projects.

  2. **Phoenix form helpers** *(planned)* — `phoenix_html`-backed
     helpers for traditional forms.

  3. **LiveView components + JS hook** *(planned)* — a drop-in
     `<.number_input>` and `<.money_input>` component pair with
     an AutoNumeric-backed JS hook for live formatting.

  A web-based visualizer is included for local development at
  `Money.Input.Visualizer`. It runs behind a config flag — see
  that module for details.

  ## Quick examples

      iex> Money.Input.Parser.parse_number("1.234,56", locale: :de)
      {:ok, Decimal.new("1234.56")}

      iex> {:ok, money} = Money.Input.Parser.parse_money("$1,234.56", locale: :en)
      iex> Money.to_string!(money, locale: :de)
      "1.234,56 $"

      iex> Money.Input.Formatter.format_money(Money.new(:USD, "1234.56"), locale: :en)
      "$1,234.56"

  """

  @doc """
  Returns the package version.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:money_input, :vsn) |> to_string()
  end
end
