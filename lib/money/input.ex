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

  * **Visualizer** — `Money.Input.Visualizer` (compiled when
    `:plug` is loaded) for local development. Behind a config
    flag — see that module.

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
    Application.spec(:money_input, :vsn) |> to_string()
  end
end
