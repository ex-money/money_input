defmodule Money.Input.Parser do
  @moduledoc """
  Front-door parser for locale-aware number and money input.

  Dispatches to `Localize.Number.Parser.parse/2` for plain
  numbers and `Money.parse/2` for currency-bearing strings. The
  input library does no parsing of its own — this module is a
  thin policy layer on top of the two existing parsers.

  ## Tolerant paste handling

  Real users paste from spreadsheets, emails, and other apps that
  may format numbers in a different convention than the user's
  display locale. The parser normalises the more obvious paste
  artefacts (NBSP, NNBSP, common dash variants, surrounding
  whitespace, accounting parentheses) before delegating.

  """

  alias Money.Input.Locale

  @typedoc "An input value parsed from a user-typed string."
  @type parsed :: Decimal.t() | integer() | Money.t()

  @doc """
  Parses a plain number from a locale-formatted string.

  ### Arguments

  * `string` is the raw user input.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:integer` — when `true`, only integers are accepted.

  ### Returns

  * `{:ok, Decimal.t()}` (or `{:ok, integer()}` when `integer:
    true`).

  * `{:error, Exception.t() | {module(), String.t()}}`.

  ### Examples

      iex> Money.Input.Parser.parse_number("1,234.56", locale: :en)
      {:ok, Decimal.new("1234.56")}

      iex> Money.Input.Parser.parse_number("1.234,56", locale: :de)
      {:ok, Decimal.new("1234.56")}

      iex> Money.Input.Parser.parse_number("", locale: :en)
      {:ok, nil}

  """
  @spec parse_number(String.t() | nil, Keyword.t()) ::
          {:ok, Decimal.t() | integer() | nil} | {:error, term()}
  def parse_number(string, options \\ [])
  def parse_number(nil, _options), do: {:ok, nil}
  def parse_number("", _options), do: {:ok, nil}

  def parse_number(string, options) when is_binary(string) do
    integer? = Keyword.get(options, :integer, false)
    parser_options = Keyword.take(options, [:locale, :number_system])

    parser_options =
      if integer?,
        do: Keyword.put(parser_options, :number, :integer),
        else: Keyword.put_new(parser_options, :number, :decimal)

    case Localize.Number.Parser.parse(normalize(string), parser_options) do
      {:ok, value} -> {:ok, value}
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a money amount from a locale-formatted string.

  ### Arguments

  * `string` is the raw user input.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.

  * `:currency` — the currency to attach when the string does not
    carry one. Required if the input has no recognisable symbol
    or ISO code.

  ### Returns

  * `{:ok, Money.t()}`, `{:ok, nil}` for blank input, or
    `{:error, term()}`.

  Use this for *user-typed strings* — locale-formatted numbers,
  optionally with a currency symbol or ISO code. For the
  structured `%{"amount", "currency"}` shape that
  `<.money_input>` submits, use `Money.Input.Cast.cast/2`
  instead (parsing and casting are different operations).

  ### Examples

      iex> {:ok, money} = Money.Input.Parser.parse_money("$1,234.56", locale: :en)
      iex> Money.to_string!(money, locale: :en)
      "$1,234.56"

      iex> {:ok, money} = Money.Input.Parser.parse_money("1.234,56", locale: :de, currency: :EUR)
      iex> Money.to_string!(money, locale: :de)
      "1.234,56 €"

  """
  @spec parse_money(String.t() | nil, Keyword.t()) ::
          {:ok, Money.t() | nil} | {:error, term()}
  def parse_money(string, options \\ [])
  def parse_money(nil, _options), do: {:ok, nil}
  def parse_money("", _options), do: {:ok, nil}

  def parse_money(string, options) when is_binary(string) do
    options = Keyword.take(options, [:locale, :currency, :default_currency])

    options =
      case Keyword.pop(options, :currency) do
        {nil, options} -> options
        {currency, options} -> Keyword.put_new(options, :default_currency, currency)
      end

    case Money.parse(normalize(string), options) do
      %Money{} = money -> {:ok, money}
      {:error, _} = error -> error
    end
  end

  @doc """
  Normalises the locale-formatted string of a parsed value to
  the canonical (period-decimal, no-grouping) form a JS form
  submission expects.

  ### Arguments

  * `value` is a `Decimal`, integer, `Money.t/0`, or `nil`.

  ### Returns

  * A binary, or `nil` when the value is `nil`.

  ### Examples

      iex> Money.Input.Parser.to_canonical(Decimal.new("1234.56"))
      "1234.56"

      iex> Money.Input.Parser.to_canonical(Money.new(:USD, "1234.56"))
      "1234.56"

      iex> Money.Input.Parser.to_canonical(nil)
      nil

  """
  @spec to_canonical(parsed() | nil) :: String.t() | nil
  def to_canonical(nil), do: nil
  def to_canonical(value) when is_integer(value), do: Integer.to_string(value)
  def to_canonical(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  def to_canonical(%Money{amount: amount}), do: Decimal.to_string(amount, :normal)

  @doc """
  Returns the locale's display data for the given locale and
  optional currency. See `Money.Input.Locale.resolve/2`.

  """
  defdelegate locale_info(locale, options \\ []), to: Locale, as: :resolve

  @doc false
  # Strip common paste artefacts. Pure, no locale awareness.
  @spec normalize(String.t()) :: String.t()
  def normalize(string) when is_binary(string) do
    string
    |> String.replace(" ", " ")
    |> String.replace(" ", " ")
    |> String.replace(" ", " ")
    |> String.replace("−", "-")
    |> String.replace("–", "-")
    |> String.replace("—", "-")
    |> String.trim()
    |> strip_accounting_parens()
  end

  defp strip_accounting_parens(string) do
    case Regex.run(~r/^\((.*)\)$/u, string) do
      [_, inner] -> "-" <> String.trim(inner)
      _ -> string
    end
  end
end
