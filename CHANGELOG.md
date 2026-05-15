# Changelog

## [v0.1.0] — 2026-05-15

* `Money.Input.Components.money_input/1` and `Money.Input.Components.currency_picker/1` — locale-aware money HEEx components backed by an AutoNumeric JS hook, submitting `%{"amount", "currency"}` maps compatible with `Money.Ecto.Composite.Type`.

* `Money.Input.Cast`, `Money.Input.Validator`, `Money.Input.Currency`, and `Money.Input.Changeset` — headless cast/validate layer with currency-aware precision (USD: 2, JPY: 0, BHD: 3) and an Ecto changeset bridge.

* `Money.Input.Visualizer` — Plug-based development tool with light/dark theme toggle that demonstrates the components across CLDR locales and currencies.
