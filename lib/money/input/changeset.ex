if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule Money.Input.Changeset do
    @moduledoc """
    Ecto.Changeset helpers for `Money.Input`.

    Only compiled when `:ecto` is loaded. Two functions, applied
    in order:

    * `cast_money/3` — converts a `%{"amount" => ..., "currency"
      => ...}` form submission into a `Money.t/0` change. Wraps
      `Money.Input.Cast.cast/2`.

    * `validate_money/3` — applies business rules (bounds,
      precision, currency match) to the cast value. Wraps
      `Money.Input.Validator.validate_money/2`.

    Plain-number fields (`:integer`, `:decimal`) are validated
    by the sibling `Localize.Inputs.Changeset.validate_number/3`.

        schema "products" do
          field :price, Money.Ecto.Composite.Type
        end

        def changeset(product, attrs) do
          product
          |> Ecto.Changeset.cast(attrs, [:price])
          |> Money.Input.Changeset.validate_money(:price,
               min: Money.new(:USD, "0.01"),
               max: Money.new(:USD, 9999))
        end

    """

    alias Ecto.Changeset
    alias Money.Input.Validator

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

        {:error, %{__exception__: true} = exception} ->
          Changeset.add_error(changeset, field, Exception.message(exception),
            validation: :money
          )
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
        {:error, %Money.Input.ValidationError{errors: errors}} -> add_errors(changeset, field, errors)
      end
    end

    defp add_errors(changeset, field, errors) do
      Enum.reduce(errors, changeset, fn {kind, message}, acc ->
        Changeset.add_error(acc, field, message, validation: kind)
      end)
    end
  end
end
