defmodule Money.Input.Cast do
  @moduledoc """
  Casts a form-submission shape into a `Money.t/0`.

  This is the structured-input counterpart to
  `Money.Input.Parser`. Where `parse_money/2` interprets a
  user-typed *string* (`"$1,234.56"`, `"1.234,56"`), `cast/2`
  consumes the *map* shape `<.money_input>` submits or that
  comes back from `Money.Ecto.Composite.Type`:

      %{"amount" => "1234.56", "currency" => "USD"}

  The function is modelled after `Money.Ecto.Composite.Type.cast/2`
  (in `money_sql`) so behaviour stays consistent across the two
  paths. We host our own copy to avoid taking on `ecto_sql` as a
  hard dependency.

  Casting is locale-aware: amounts can arrive locale-formatted
  (`"1.234,56"`) when the AutoNumeric JS hook isn't loaded.
  `cast/2` parses them via `Money.new/3`, which is locale-aware
  when `:locale` is in `options`.

  """

  @typedoc """
  Inputs accepted by `cast/2`.

  * `nil` and blank-amount maps return `{:ok, nil}` — the field
    wasn't filled in.
  * `Money.t/0` is round-tripped.
  * A `%{"amount", "currency"}` (or `%{amount, currency}`) map
    is the nested form-submission shape.
  * A binary delegates to `Money.Input.Parser.parse_money/2` for
    convenience; prefer `parse_money` directly when you know the
    input is a user-typed string.
  """
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
    `Money.new/3` (and to `Money.Input.Parser.parse_money/2`
    when `input` is a string).

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
    currency = Map.get(map, "currency") || Map.get(map, :currency) || Keyword.get(options, :currency)

    do_cast(currency, amount, options)
  end

  def cast(string, options) when is_binary(string) do
    Money.Input.Parser.parse_money(string, options)
  end

  def cast(_other, _options) do
    {:error,
     {ArgumentError, "input must be a Money.t, a map with amount and currency, or a string"}}
  end

  # ── internal ────────────────────────────────────────────────

  defp do_cast(_currency, "", _options), do: {:ok, nil}
  defp do_cast(_currency, nil, _options), do: {:ok, nil}

  defp do_cast(nil, _amount, _options),
    do: {:error, {Money.UnknownCurrencyError, "Currency must not be nil"}}

  defp do_cast(currency, amount, options) do
    case Money.new(currency, amount, money_new_options(options)) do
      %Money{} = money -> {:ok, money}
      {:error, _} = error -> error
    end
  end

  # `Money.new/3` parses string amounts locale-aware when `:locale`
  # is supplied, so this is the bridge to our caller's locale. Any
  # other options (e.g. `:fractional_digits`) are forwarded as-is.
  defp money_new_options(options) do
    Keyword.take(options, [:locale, :fractional_digits, :no_round, :rounding_mode])
  end
end
