defmodule Money.Input do
  @moduledoc """
  Locale-aware money form input.

  This package ships:

  * **Headless** — `Money.Input.Cast`, `Money.Input.Validator`,
    `Money.Input.Currency`. Pure Elixir, no Phoenix dependency.
    User-typed strings are parsed by `Money.parse/2`; money
    formatting is `Money.to_string/2` directly — there are no
    wrappers here.

  * **Ecto** — `Money.Input.Changeset` (compiled when `:ecto`
    is loaded).

  * **HEEx components** — `Money.Input.Components` (compiled
    when `:phoenix_live_view` is loaded). Ships `<.money_input>`
    and `<.currency_picker>` plus an AutoNumeric-backed JS hook
    in `priv/static/money_input.js`.

  For a Plug-based visualizer that demos every component across
  CLDR locales and currencies, see the sibling
  [`money_input_playground`](https://github.com/ex-money/money_input_playground)
  package — useful during local development, deployable to Fly.io.

  For plain *number* inputs (no currency), see the sibling
  [`localize_inputs`](https://hex.pm/packages/localize_inputs)
  package — `<.number_input>` lives there.

  ## Quick examples

      iex> {:ok, money} = Money.Input.Cast.cast(
      ...>   %{"amount" => "1.234,56", "currency" => "EUR"},
      ...>   locale: :de
      ...> )
      iex> Money.to_string!(money, locale: :de)
      "1.234,56 €"

      iex> Money.to_string!(Money.new(:USD, "1234.56"), locale: :en)
      "$1,234.56"

      iex> Money.to_string!(Money.new(:EUR, "1234.56"), locale: :de, currency_symbol: :none)
      "1.234,56"

  """

  @doc """
  Returns the installed package version as a string.

  ### Returns

  * The version string declared in `mix.exs`.

  ### Examples

      iex> Money.Input.version() |> Version.parse!()
      iex> :ok
      :ok

  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ex_money_input, :vsn) |> to_string()
  end
end
