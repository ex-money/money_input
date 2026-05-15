if Code.ensure_loaded?(Gettext.Backend) do
  defmodule Money.Input.Gettext do
    @moduledoc """
    Gettext backend for `ex_money_input` UI strings.

    Hosts the message catalog for the currency picker's labels —
    placeholders, aria labels, section headings, empty-state text.
    The catalog lives in `priv/gettext/` and ships with English
    source plus a starter set of locale translations; downstream
    apps can add or override translations by configuring their own
    Gettext backend and merging the `.po` files.

    Activated only when the host project depends on `:gettext`.
    The components module gates its `use Localize.Message.Sigils`
    call on this backend being available.
    """
    use Gettext.Backend, otp_app: :ex_money_input
  end
end
