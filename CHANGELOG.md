# Changelog

## [v0.2.0] — 2026-05-15

* Gettext-backed localization of the picker's UI strings (aria labels, search placeholder, section headers, empty-state). Catalog ships English source plus de, fr, and ja translations. Activated via `Money.Input.Gettext` backend. `:gettext` is now a required dep when the components are used (it was optional in 0.1).

* Currency names in the picker rendering localize to the active locale via `Localize.Currency.display_name/2` instead of the static English `:name` field.

* `Money.Input.Visualizer` and the standalone helper have moved to the sibling [`money_input_playground`](https://github.com/ex-money/money_input_playground) package (under the `MoneyInputPlayground.Visualizer` namespace). Drops the `:plug` and `:bandit` optional deps from this package. If you embedded the visualizer in your own router via `forward "/money-input", Money.Input.Visualizer`, add `{:money_input_playground, "~> 0.1", only: :dev}` and update the forward target to `MoneyInputPlayground.Visualizer`.

## [v0.1.0] — 2026-05-15

* `Money.Input.Components.money_input/1` and `Money.Input.Components.currency_picker/1` — locale-aware money HEEx components backed by an AutoNumeric JS hook, submitting `%{"amount", "currency"}` maps compatible with `Money.Ecto.Composite.Type`.

* `Money.Input.Cast`, `Money.Input.Validator`, `Money.Input.Currency`, and `Money.Input.Changeset` — headless cast/validate layer with currency-aware precision (USD: 2, JPY: 0, BHD: 3) and an Ecto changeset bridge.

* `Money.Input.Visualizer` — Plug-based development tool with light/dark theme toggle that demonstrates the components across CLDR locales and currencies.
