if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule Money.Input.Changeset do
    @moduledoc """
    Ecto.Changeset helpers for `Money.Input`.

    Only compiled when `:ecto` is loaded. Wraps
    `Money.Input.Validator` so the validation rules used at the
    form layer (range, precision, required, currency match) are
    the same ones applied at the changeset layer.

        schema "products" do
          field :price, Money.Ecto.Composite.Type
          field :quantity, :decimal
        end

        def changeset(product, attrs) do
          product
          |> Ecto.Changeset.cast(attrs, [:price, :quantity])
          |> Money.Input.Changeset.validate_money(:price,
               min: Money.new(:USD, "0.01"),
               max: Money.new(:USD, 9999))
          |> Money.Input.Changeset.validate_number(:quantity, min: 1)
        end

    """

    alias Ecto.Changeset
    alias Money.Input.Validator

    @doc """
    Validates a `Decimal` / integer field with the rules from
    `Money.Input.Validator.validate_number/2`.

    ### Arguments

    * `changeset` is an `Ecto.Changeset`.

    * `field` is the field name.

    * `options` is a keyword list forwarded to the validator
      (`:min`, `:max`, `:decimals`, `:required`).

    ### Returns

    * The changeset, with any errors added.

    ### Examples

        iex> changeset = Ecto.Changeset.cast({%{}, %{quantity: :integer}}, %{"quantity" => 5}, [:quantity])
        iex> changeset = Money.Input.Changeset.validate_number(changeset, :quantity, min: 1, max: 10)
        iex> changeset.valid?
        true

    """
    @spec validate_number(Ecto.Changeset.t(), atom(), Keyword.t()) :: Ecto.Changeset.t()
    def validate_number(%Changeset{} = changeset, field, options \\ []) do
      value = Changeset.get_field(changeset, field)

      case Validator.validate_number(value, options) do
        :ok -> changeset
        {:error, errors} -> add_errors(changeset, field, errors)
      end
    end

    @doc """
    Casts a nested `%{"amount" => ..., "currency" => ...}` form
    submission into a `Money.t/0` and puts it on the changeset.

    Use this when the field is **not** typed as
    `Money.Ecto.Composite.Type` (which casts the same map shape
    automatically). Delegates to `Money.Input.Cast.cast/2`, which
    is locale-aware via `Money.new/3`, so casting works even in
    the Path A fallback when the AutoNumeric JS hook isn't loaded.

    ### Arguments

    * `changeset` is an `Ecto.Changeset`.

    * `field` is the field name.

    * `options` is a keyword list.

    ### Options

    * `:locale` — locale to parse the amount under. Defaults to
      `Localize.get_locale/0`.

    * `:currency` — fallback currency if the submitted map omits
      the `currency` key.

    ### Returns

    * The changeset with a `Money.t/0` change put on `field`, or
      with an error added if the amount/currency can't be parsed.

    """
    @spec cast_money(Ecto.Changeset.t(), atom(), Keyword.t()) :: Ecto.Changeset.t()
    def cast_money(%Changeset{} = changeset, field, options \\ []) do
      raw = Map.get(changeset.params || %{}, Atom.to_string(field))

      case Money.Input.Cast.cast(raw, options) do
        {:ok, nil} ->
          changeset

        {:ok, money} ->
          Changeset.put_change(changeset, field, money)

        {:error, {_, message}} when is_binary(message) ->
          Changeset.add_error(changeset, field, message, validation: :money)

        {:error, _} ->
          Changeset.add_error(changeset, field, "is invalid", validation: :money)
      end
    end

    @doc """
    Validates a `Money.t/0` field with the rules from
    `Money.Input.Validator.validate_money/2`.

    ### Arguments

    * `changeset` is an `Ecto.Changeset`.

    * `field` is the field name.

    * `options` is a keyword list forwarded to the validator
      (`:min`, `:max`, `:required`, `:currency`).

    ### Returns

    * The changeset, with any errors added.

    """
    @spec validate_money(Ecto.Changeset.t(), atom(), Keyword.t()) :: Ecto.Changeset.t()
    def validate_money(%Changeset{} = changeset, field, options \\ []) do
      value = Changeset.get_field(changeset, field)

      case Validator.validate_money(value, options) do
        :ok -> changeset
        {:error, errors} -> add_errors(changeset, field, errors)
      end
    end

    defp add_errors(changeset, field, errors) do
      Enum.reduce(errors, changeset, fn {kind, message}, acc ->
        Changeset.add_error(acc, field, message, validation: kind)
      end)
    end
  end
end
