defmodule Money.Input.Formatter do
  @moduledoc """
  Server-side formatter for number and money input values.

  This is the *blur* formatter — what the server renders into the
  input's `value` attribute after a round-trip when the JS hook
  isn't active (Path A fallback) or for the initial server
  render. Live, as-you-type formatting is the JS hook's job.

  Delegates to `Localize.Number.to_string/2` and
  `Money.to_string/2`; this module does no formatting of its own.

  """

  @doc """
  Formats a parsed value for display in a number input.

  ### Arguments

  * `value` is a `Decimal`, integer, float, string, or `nil`.

  * `options` is a keyword list passed through to
    `Localize.Number.to_string/2`.

  ### Returns

  * The formatted string. `nil` and blank string inputs return
    `""` so they can be assigned directly to `value` attributes.

  ### Examples

      iex> Money.Input.Formatter.format_number(Decimal.new("1234.56"), locale: :en)
      "1,234.56"

      iex> Money.Input.Formatter.format_number(Decimal.new("1234.56"), locale: :de)
      "1.234,56"

      iex> Money.Input.Formatter.format_number(nil)
      ""

  """
  @spec format_number(term(), Keyword.t()) :: String.t()
  def format_number(value, options \\ [])
  def format_number(nil, _options), do: ""
  def format_number("", _options), do: ""

  def format_number(value, options) when is_binary(value) do
    case Money.Input.Parser.parse_number(value, options) do
      {:ok, nil} -> ""
      {:ok, parsed} -> format_number(parsed, options)
      {:error, _} -> value
    end
  end

  def format_number(value, options) do
    case Localize.Number.to_string(value, options) do
      {:ok, formatted} -> formatted
      _ -> to_string(value)
    end
  end

  @doc """
  Formats a `Money.t/0` value for display in a money input.

  ### Arguments

  * `value` is a `Money.t/0`, a `Decimal` (with the currency
    supplied via options), or `nil`.

  * `options` is a keyword list.

  ### Options

  * `:locale` — the locale.

  * `:currency` — used when `value` is not a `Money.t/0`.

  * `:no_symbol` — when `true`, returns just the number portion
    of the format. Useful when the symbol is rendered as a
    separate adornment outside the input.

  ### Returns

  * A formatted string. `nil` returns `""`.

  ### Examples

      iex> Money.Input.Formatter.format_money(Money.new(:USD, "1234.56"), locale: :en)
      "$1,234.56"

      iex> Money.Input.Formatter.format_money(Money.new(:USD, "1234.56"), locale: :en, no_symbol: true)
      "1,234.56"

      iex> Money.Input.Formatter.format_money(nil)
      ""

  """
  @spec format_money(term(), Keyword.t()) :: String.t()
  def format_money(value, options \\ [])
  def format_money(nil, _options), do: ""
  def format_money("", _options), do: ""

  def format_money(value, options) when is_binary(value) do
    case Money.Input.Parser.parse_money(value, options) do
      {:ok, nil} -> ""
      {:ok, money} -> format_money(money, options)
      {:error, _} -> value
    end
  end

  def format_money(%Money{} = money, options) do
    {no_symbol, options} = Keyword.pop(options, :no_symbol, false)

    if no_symbol do
      # Drop :currency from the options when formatting just the
      # number portion, otherwise Localize.Number.to_string adds
      # the currency symbol back in.
      format_number(money.amount, Keyword.drop(options, [:currency]))
    else
      case Money.to_string(money, options) do
        {:ok, formatted} -> formatted
        _ -> Money.to_string!(money)
      end
    end
  end

  def format_money(%Decimal{} = decimal, options) do
    case Keyword.fetch(options, :currency) do
      {:ok, currency} -> format_money(Money.new(currency, decimal), options)
      :error -> format_number(decimal, options)
    end
  end
end
