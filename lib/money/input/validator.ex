defmodule Money.Input.Validator do
  @moduledoc """
  Business-rule validation for `t:Money.t/0` values.

  ## Why this is separate from `Money.Input.Cast`

  `Money.Input.Cast.cast/2` answers the question *"can I turn
  this user input into a Money?"* — shape and parse validation
  only. It rejects missing currencies and unparseable amounts.

  This module answers the question *"is this Money acceptable
  under my business rules?"* — bounds (`:min`/`:max`),
  required-ness, an enforced currency, and currency-aware
  fractional-digit precision (USD ≤ 2, JPY ≤ 0, BHD ≤ 3).
  `Money.new(:JPY, "1.5")` is shape-valid but business-invalid
  for most apps.

  Both pieces are usually wired through the `Ecto.Changeset`
  helpers in `Money.Input.Changeset` — `cast_money/3` then
  `validate_money/3`.

  """

  alias Money.Input.ValidationError

  @doc """
  Validates a `t:Money.t/0` against bounds, precision, and
  required-ness.

  ### Arguments

  * `value` is a `t:Money.t/0` or `nil`.

  * `options` is a keyword list of options.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min` — minimum allowed value. A `t:Money.t/0`, or any value
    `Money.new/2` accepts (e.g. a `Decimal` or string) — when
    the latter, the bound takes the value's currency.

  * `:max` — maximum allowed value. Same shape options as
    `:min`.

  * `:currency` — when set, enforces that the value's currency
    matches.

  ### Returns

  * `:ok` when every check passes.

  * `{:error, %Money.Input.ValidationError{errors: [{atom(),
    String.t()}]}}` with one entry per failing check, in the
    order `:required`, `:currency`, `:decimals`, `:min`, `:max`.
    `Money.Input.Changeset.validate_money/3` unpacks the entries
    into per-field changeset errors.

  ### Examples

      iex> Money.Input.Validator.validate_money(Money.new(:USD, "1234.56"), max: Money.new(:USD, "10000"))
      :ok

      iex> {:error, %Money.Input.ValidationError{errors: errors}} =
      ...>   Money.Input.Validator.validate_money(Money.new(:USD, "1.234"), max: Money.new(:USD, "10000"))
      iex> errors
      [{:decimals, "must have at most 2 fractional digits"}]

      iex> {:error, %Money.Input.ValidationError{errors: errors}} =
      ...>   Money.Input.Validator.validate_money(Money.new(:USD, 1), currency: :EUR)
      iex> errors
      [{:currency, "must be EUR"}]

  """
  @spec validate_money(term(), Keyword.t()) :: :ok | {:error, ValidationError.t()}
  def validate_money(value, options \\ []) do
    errors =
      []
      |> check_required(value, options)
      |> check_currency(value, options)
      |> check_money_precision(value)
      |> check_money_range(value, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, ValidationError.exception(errors: errors)}
  end

  defp check_required(errors, nil, options) do
    if Keyword.get(options, :required, false) do
      [{:required, "is required"} | errors]
    else
      errors
    end
  end

  defp check_required(errors, _value, _options), do: errors

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

  # Non-Money input (binary, atom, map, etc.) — skip range
  # check. The `check_currency` / `check_money_precision`
  # clauses surface the type mismatch as a validation error;
  # we don't want range-check to raise on top of that.
  defp check_money_range(errors, _value, _options), do: errors

  defp maybe_check_min(errors, _value, nil), do: errors

  defp maybe_check_min(errors, value, min) do
    case Money.cmp(value, min) do
      -1 -> [{:min, "must be at least #{Money.to_string!(min)}"} | errors]
      _ -> errors
    end
  end

  defp maybe_check_max(errors, _value, nil), do: errors

  defp maybe_check_max(errors, value, max) do
    case Money.cmp(value, max) do
      1 -> [{:max, "must be at most #{Money.to_string!(max)}"} | errors]
      _ -> errors
    end
  end

  defp normalize_money_bound(nil, _value), do: nil
  defp normalize_money_bound(%Money{} = bound, _value), do: bound

  defp normalize_money_bound(bound, %Money{currency: currency}) do
    Money.new(currency, bound)
  end

  defp decimal_places(%Decimal{exp: exp}) when exp < 0, do: -exp
  defp decimal_places(%Decimal{}), do: 0
  defp decimal_places(value) when is_integer(value), do: 0
end
