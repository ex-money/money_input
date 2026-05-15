defmodule Money.Input.Cast do
  @moduledoc """
  Casts a form-submission shape into a `Money.t/0`.

  `cast/2` consumes the four shapes a user-input pipeline can
  produce:

  * `nil` and blank-amount maps return `{:ok, nil}` — the field
    wasn't filled in.

  * `Money.t/0` round-trips unchanged.

  * `%{"amount", "currency"}` (or `%{amount, currency}`) — the
    nested form-submission shape that `<.money_input>` produces
    and that `Money.Ecto.Composite.Type` accepts. The amount
    field is built with `Money.new/3`; pass `:locale` if you
    need to parse a locale-formatted amount string.

  * A bare binary (`"$1,234.56"`, `"1.234,56"`) delegates to
    `Money.parse/2`. Money.parse already handles surrounding
    whitespace, accounting parens, currency symbols and ISO
    codes.

  The function is modelled after `Money.Ecto.Composite.Type.cast/2`
  (in `money_sql`) so behaviour stays consistent across the two
  paths. We host our own copy to avoid taking on `ecto_sql` as a
  hard dependency.

  """

  @typedoc "Inputs accepted by `cast/2`. See the module docs."
  @type input ::
          nil
          | Money.t()
          | String.t()
          | %{required(String.t() | atom()) => term()}

  @doc """
  Casts a form-submission value to a `Money.t/0`.

  ### Arguments

  * `input` is the value to cast (see `t:input/0`).

  * `options` is a keyword list of options forwarded to
    `Money.new/3` for map inputs and `Money.parse/2` for string
    inputs.

  ### Options

  * `:locale` — locale to use when parsing a locale-formatted
    amount string. Defaults to `Localize.get_locale/0`.

  * `:currency` — fallback currency atom used only when the
    submitted map omits the `currency` key. Has no effect when
    the map provides one.

  ### Returns

  * `{:ok, Money.t()}` on success.

  * `{:ok, nil}` for blank input — `nil`, `""`, a map with an
    empty `amount`, or a map with no `amount` key at all.

  * `{:error, term()}` if the cast fails — typically an
    `{exception, message}` tuple.

  ### Examples

      iex> Money.Input.Cast.cast(%{"amount" => "1234.56", "currency" => "USD"})
      {:ok, Money.new(:USD, "1234.56")}

      iex> Money.Input.Cast.cast(%{"amount" => "1.234,56", "currency" => "EUR"}, locale: :de)
      {:ok, Money.new(:EUR, "1234.56")}

      iex> Money.Input.Cast.cast(%{"amount" => "10"}, currency: :JPY)
      {:ok, Money.new(:JPY, "10")}

      iex> Money.Input.Cast.cast(%{"amount" => "", "currency" => "USD"})
      {:ok, nil}

      iex> Money.Input.Cast.cast(nil)
      {:ok, nil}

      iex> Money.Input.Cast.cast(Money.new(:GBP, "5.00"))
      {:ok, Money.new(:GBP, "5.00")}

  """
  @spec cast(input(), Keyword.t()) :: {:ok, Money.t() | nil} | {:error, term()}
  def cast(input, options \\ [])

  def cast(nil, _options), do: {:ok, nil}
  def cast(%Money{} = money, _options), do: {:ok, money}

  def cast(%{"amount" => "", "currency" => _}, _options), do: {:ok, nil}
  def cast(%{"amount" => nil, "currency" => _}, _options), do: {:ok, nil}

  def cast(%{} = map, options) do
    amount = Map.get(map, "amount") || Map.get(map, :amount)

    currency =
      Map.get(map, "currency") || Map.get(map, :currency) || Keyword.get(options, :currency)

    do_cast(currency, amount, options)
  end

  def cast("", _options), do: {:ok, nil}

  def cast(string, options) when is_binary(string) do
    # `Money.parse/2` already handles surrounding whitespace,
    # accounting parens, and currency symbols/ISO codes natively.
    # The only translation we do is `:currency` → `:default_currency`
    # so the API surface here matches the map clause above.
    money_parse_options =
      case Keyword.pop(options, :currency) do
        {nil, options} -> options
        {currency, options} -> Keyword.put_new(options, :default_currency, currency)
      end

    string
    |> Money.parse(money_parse_options)
    |> normalise_money_result()
  end

  def cast(_other, _options) do
    {:error,
     ArgumentError.exception(
       "input must be a Money.t, a map with amount and currency, or a string"
     )}
  end

  # ── internal ────────────────────────────────────────────────

  defp do_cast(_currency, "", _options), do: {:ok, nil}
  defp do_cast(_currency, nil, _options), do: {:ok, nil}

  defp do_cast(nil, _amount, _options),
    do: {:error, Money.UnknownCurrencyError.exception("Currency must not be nil")}

  defp do_cast(currency, amount, options) do
    currency
    |> Money.new(amount, money_new_options(options))
    |> normalise_money_result()
  end

  # `Money.parse/2` and `Money.new/3` both return their errors as
  # `{module, message}` tuples — Money's legacy convention. Lift
  # them into proper exception structs at this library's
  # boundary so the public API exposes one consistent shape.
  defp normalise_money_result(%Money{} = money), do: {:ok, money}

  defp normalise_money_result({:error, {module, message}}) when is_atom(module),
    do: {:error, module.exception(message)}

  # `Money.new/3` parses string amounts locale-aware when `:locale`
  # is supplied, so this is the bridge to our caller's locale. Any
  # other options (e.g. `:fractional_digits`) are forwarded as-is.
  defp money_new_options(options) do
    Keyword.take(options, [:locale, :fractional_digits, :no_round, :rounding_mode])
  end
end
