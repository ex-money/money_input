# Changelog

## [v0.3.0] — 2026-07-31

### Changed

* Requires `localize ~> 1.0` and `ex_money ~> 6.2`. The previous requirements excluded Localize 1.0.

## [v0.2.3] — 2026-05-17

### Bug Fixes

* `Money.Input.Validator.validate_money/2` no longer raises `FunctionClauseError` when called with a non-`%Money{}` value (binary, atom, map, etc.). `check_money_range/3` now has a final catch-all that skips the range check on type mismatch.

* `<.money_input>` no longer raises when `:min` / `:max` is a value Phoenix can't render as iodata — `value_attr/1` rescues `Protocol.UndefinedError` and drops the attribute.

* `<.money_input>` with an unknown `:locale` no longer 500s on downstream `@locale_data.X` reads. The placeholder when both the requested locale AND its fallback fail to resolve is now a shaped `%Money.Input.Currency{}` struct (all fields `nil`) rather than a bare `%{}` — so attribute reads degrade to `nil` and Phoenix omits the attribute.

* `<.currency_picker>` no longer raises on `:preferred` non-list values (`nil`, atom, integer). `assign_picker/1` coerces to `[]` and writes the safe value back to assigns so the template's `Enum.map_join(@preferred, ...)` reads the coerced value.

* Adversarial-input test suite added (`test/adversarial_render_test.exs`) that exercises every public component with a matrix of bad attr values, and an atom-safety guard (`test/atom_safety_test.exs`) that fails the suite if any new `String.to_atom/1` is added to `lib/`.

## [v0.2.2] — 2026-05-17

### Bug Fixes

* Currency picker's search `<input>` field now picks up the dark theme. The element had no explicit `background`/`color` declarations, so it fell back to the browser-default white/black even when the rest of the picker overlay correctly used the dark `--mi-*` tokens.

## [v0.2.1] — 2026-05-17

### Bug Fixes

* `Money.Input.Components.money_input/1` no longer raises when the form submits an empty or unknown currency (e.g. the picker's hidden carrier before any selection). `normalize_currency_code/1` blacklists `""` and `:""`, and `assign_money_locale_data/1` falls back to the locale's natural currency on unknown ISO codes instead of `MatchError`.

* `Money.Input.Components.currency_picker/1` tolerates an unknown locale — `assign_picker/1` now falls back to a placeholder rather than crashing on `{:ok, _} = ...`.

* Dark-mode CSS tokens added — `priv/static/money_input.css` now ships `@media (prefers-color-scheme: dark)` and `[data-theme="dark"]` override blocks so the picker and money input pick up the host page's dark theme instead of staying light-themed.

## [v0.2.0] — 2026-05-15

* Gettext-backed localization of the picker's UI strings (aria labels, search placeholder, section headers, empty-state). Catalog ships English source plus de, fr, and ja translations. Activated via `Money.Input.Gettext` backend. `:gettext` is now a required dep when the components are used (it was optional in 0.1).

* Currency names in the picker rendering localize to the active locale via `Localize.Currency.display_name/2` instead of the static English `:name` field.

* `Money.Input.Visualizer` and the standalone helper have moved to the sibling [`money_input_playground`](https://github.com/ex-money/money_input_playground) package (under the `MoneyInputPlayground.Visualizer` namespace). Drops the `:plug` and `:bandit` optional deps from this package. If you embedded the visualizer in your own router via `forward "/money-input", Money.Input.Visualizer`, add `{:money_input_playground, "~> 0.1", only: :dev}` and update the forward target to `MoneyInputPlayground.Visualizer`.

## [v0.1.0] — 2026-05-15

* `Money.Input.Components.money_input/1` and `Money.Input.Components.currency_picker/1` — locale-aware money HEEx components backed by an AutoNumeric JS hook, submitting `%{"amount", "currency"}` maps compatible with `Money.Ecto.Composite.Type`.

* `Money.Input.Cast`, `Money.Input.Validator`, `Money.Input.Currency`, and `Money.Input.Changeset` — headless cast/validate layer with currency-aware precision (USD: 2, JPY: 0, BHD: 3) and an Ecto changeset bridge.

* `Money.Input.Visualizer` — Plug-based development tool with light/dark theme toggle that demonstrates the components across CLDR locales and currencies.
