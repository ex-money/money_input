defmodule Money.Input.ValidationError do
  @moduledoc """
  Raised by `Money.Input.Validator.validate_money/2` when one or
  more business-rule checks fail (bounds, precision, required,
  currency match).

  Wraps a list of `{kind, message}` entries — one per failing
  check. `Money.Input.Changeset.validate_money/3` unpacks this
  list and converts each entry into an `Ecto.Changeset` error
  with `validation: kind` metadata.

  """

  @typedoc "A single failed check: `{kind, message}`."
  @type entry :: {atom(), String.t()}

  defexception errors: []

  @type t :: %__MODULE__{errors: [entry()]}

  @impl true
  def exception(bindings) when is_list(bindings) do
    case Keyword.fetch(bindings, :errors) do
      {:ok, errors} -> %__MODULE__{errors: errors}
      :error -> struct!(__MODULE__, bindings)
    end
  end

  @impl true
  def message(%__MODULE__{errors: []}), do: "validation failed"

  def message(%__MODULE__{errors: errors}) do
    errors
    |> Enum.map_join("; ", fn {kind, msg} -> "#{kind}: #{msg}" end)
  end
end
