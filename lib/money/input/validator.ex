defmodule Money.Input.Validator do
  @moduledoc """
  Server-side validation for parsed number and money input values.

  The validator is intentionally currency-aware: USD allows two
  fractional digits, JPY allows zero, BHD allows three. Submitting
  a value with more decimals than the currency permits is
  rejected.

  """

  @typedoc "An error produced by the validator."
  @type error :: {atom(), String.t()}

  @doc """
  Validates a parsed number.

  ### Arguments

  * `value` is a `Decimal`, integer, or `nil`.

  * `options` is a keyword list.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min` / `:max` — numeric bounds (any value the parser
    accepts).

  * `:decimals` — maximum number of fractional digits.

  ### Returns

  * `:ok` on success, or `{:error, [error()]}`.

  ### Examples

      iex> Money.Input.Validator.validate_number(Decimal.new("5"), min: 1, max: 10)
      :ok

      iex> Money.Input.Validator.validate_number(Decimal.new("15"), max: 10)
      {:error, [{:max, "must be at most 10"}]}

      iex> Money.Input.Validator.validate_number(nil, required: true)
      {:error, [{:required, "is required"}]}

  """
  @spec validate_number(term(), Keyword.t()) :: :ok | {:error, [error()]}
  def validate_number(value, options \\ []) do
    errors =
      []
      |> check_required(value, options)
      |> check_range(value, options)
      |> check_decimals(value, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, errors}
  end

  @doc """
  Validates a parsed money value.

  ### Arguments

  * `value` is a `Money.t/0` or `nil`.

  * `options` is a keyword list.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min` / `:max` — `Money.t/0` (or a value the parser
    accepts).

  * `:currency` — when set, enforces that the value's currency
    matches.

  ### Returns

  * `:ok` or `{:error, [error()]}`.

  ### Examples

      iex> Money.Input.Validator.validate_money(Money.new(:USD, "1234.56"), max: Money.new(:USD, "10000"))
      :ok

      iex> Money.Input.Validator.validate_money(Money.new(:USD, "1.234"), max: Money.new(:USD, "10000"))
      {:error, [{:decimals, "must have at most 2 fractional digits"}]}

      iex> Money.Input.Validator.validate_money(Money.new(:USD, 1), currency: :EUR)
      {:error, [{:currency, "must be EUR"}]}

  """
  @spec validate_money(term(), Keyword.t()) :: :ok | {:error, [error()]}
  def validate_money(value, options \\ []) do
    errors =
      []
      |> check_required(value, options)
      |> check_currency(value, options)
      |> check_money_precision(value)
      |> check_money_range(value, options)

    errors = Enum.reverse(errors)
    if errors == [], do: :ok, else: {:error, errors}
  end

  defp check_required(errors, nil, options) do
    if Keyword.get(options, :required, false) do
      [{:required, "is required"} | errors]
    else
      errors
    end
  end

  defp check_required(errors, _value, _options), do: errors

  defp check_range(errors, nil, _options), do: errors

  defp check_range(errors, value, options) do
    errors
    |> maybe_check_min(value, Keyword.get(options, :min))
    |> maybe_check_max(value, Keyword.get(options, :max))
  end

  defp maybe_check_min(errors, _value, nil), do: errors

  defp maybe_check_min(errors, value, min) do
    if compare(value, min) == :lt do
      [{:min, "must be at least #{describe(min)}"} | errors]
    else
      errors
    end
  end

  defp maybe_check_max(errors, _value, nil), do: errors

  defp maybe_check_max(errors, value, max) do
    if compare(value, max) == :gt do
      [{:max, "must be at most #{describe(max)}"} | errors]
    else
      errors
    end
  end

  defp check_decimals(errors, nil, _options), do: errors

  defp check_decimals(errors, value, options) do
    case Keyword.get(options, :decimals) do
      nil ->
        errors

      max_decimals ->
        if decimal_places(value) > max_decimals do
          [{:decimals, "must have at most #{max_decimals} fractional digits"} | errors]
        else
          errors
        end
    end
  end

  defp check_currency(errors, %Money{currency: code}, options) do
    case Keyword.get(options, :currency) do
      nil -> errors
      ^code -> errors
      expected -> [{:currency, "must be #{expected}"} | errors]
    end
  end

  defp check_currency(errors, _value, _options), do: errors

  defp check_money_precision(errors, %Money{currency: code, amount: amount}) do
    iso_digits =
      case Money.Currency.currency_for_code(code) do
        {:ok, %{iso_digits: digits}} -> digits
        _ -> nil
      end

    if iso_digits && decimal_places(amount) > iso_digits do
      [{:decimals, "must have at most #{iso_digits} fractional digits"} | errors]
    else
      errors
    end
  end

  defp check_money_precision(errors, _value), do: errors

  defp check_money_range(errors, nil, _options), do: errors

  defp check_money_range(errors, %Money{} = value, options) do
    errors
    |> maybe_check_min(value, normalize_money_bound(Keyword.get(options, :min), value))
    |> maybe_check_max(value, normalize_money_bound(Keyword.get(options, :max), value))
  end

  defp normalize_money_bound(nil, _value), do: nil
  defp normalize_money_bound(%Money{} = bound, _value), do: bound

  defp normalize_money_bound(bound, %Money{currency: currency}) do
    Money.new(currency, to_string(bound))
  end

  defp compare(%Money{} = a, %Money{} = b) do
    case Money.cmp(a, b) do
      {:error, _} -> :eq
      result -> result
    end
  end

  defp compare(%Decimal{} = a, %Decimal{} = b), do: Decimal.compare(a, b)
  defp compare(%Decimal{} = a, b), do: Decimal.compare(a, to_decimal(b))
  defp compare(a, %Decimal{} = b), do: Decimal.compare(to_decimal(a), b)

  defp compare(a, b) when is_integer(a) and is_integer(b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  defp compare(a, b), do: Decimal.compare(to_decimal(a), to_decimal(b))

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp describe(value) do
    case value do
      %Money{} = money -> Money.to_string!(money)
      other -> to_string(other)
    end
  end

  defp decimal_places(%Money{amount: amount}), do: decimal_places(amount)

  defp decimal_places(%Decimal{exp: exp}) when exp < 0, do: -exp
  defp decimal_places(%Decimal{}), do: 0
  defp decimal_places(value) when is_integer(value), do: 0

  defp decimal_places(value) when is_binary(value) do
    case String.split(value, ".") do
      [_, fraction] -> String.length(fraction)
      _ -> 0
    end
  end

  defp decimal_places(_), do: 0
end
