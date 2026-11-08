# Money.Input

Locale-aware money form input — `<.money_input>` and `<.currency_picker>` Phoenix HEEx components, an AutoNumeric-backed JS hook, and an Ecto changeset bridge. For a plain *number* input (no currency), see the sibling [`localize_inputs`](https://hex.pm/packages/localize_inputs) package, where `<.number_input>` lives.

## Features

* **`<.money_input>`** — a money field that formats the amount for the user's locale, renders the currency symbol as an adornment outside the input, and applies the currency's precision (USD 2, JPY 0, BHD 3), with an optional embedded currency picker.

* **`<.currency_picker>`** — a searchable currency picker with flags, recent selections, preferred currencies, keyboard navigation and a full-screen sheet on mobile.

* **Live formatting** — an AutoNumeric-backed LiveView hook formats the amount as the user types. Without it the inputs still work and the server parses whatever was typed.

* **One submission shape** — the field always submits `%{"amount" => ..., "currency" => ...}`, which `Money.Ecto.Composite.Type` and `Money.Input.Changeset.cast_money/3` accept directly.

* **Headless layer** — `Money.Input.Cast`, `Money.Input.Validator` and `Money.Input.Currency` work without Phoenix or Ecto.

## Supported Elixir and OTP versions

Money.Input supports **Elixir 1.17** and later on **OTP 26** and later.

## Installation

```elixir
def deps do
  [
    {:ex_money_input, "~> 0.3.1"},

    # Components and changeset bridge:
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:ecto, "~> 3.10"}
  ]
end
```

Every Phoenix and Ecto dependency is optional — the headless layer compiles without any of them, and each higher layer activates when its dependency is present.

## Quick start

Import the components with `import Money.Input.Components` in your view or `use` block, then:

```heex
<%!-- Single fixed currency --%>
<.money_input form={@form} field={:price} default_currency={:USD} />

<%!-- Currency-selectable with the bundled picker --%>
<.money_input
  form={@form}
  field={:price}
  default_currency={:USD}
  currency_picker={true}
  preferred_currencies={[:USD, :EUR, :GBP, :JPY]}
/>

<%!-- Standalone picker (e.g. "show prices in" widget) --%>
<.currency_picker
  current={@viewing_currency}
  form={@form}
  field={:viewing_currency}
  preferred={[:USD, :EUR, :GBP]}
/>
```

The `<.money_input>` field always submits two nested keys, whether the picker is on or not:

```elixir
%{"product" => %{"price" => %{"amount" => "1234.56", "currency" => "USD"}}}
```

That shape is exactly what `Money.Ecto.Composite.Type.cast/1` and `Money.Input.Changeset.cast_money/3` accept.

## JS hook (AutoNumeric)

Add the peer dependency:

```bash
npm install autonumeric
```

In `assets/js/app.js`:

```javascript
import AutoNumeric from "autonumeric"
import Hooks from "ex_money_input"

Hooks.configure({ AutoNumeric })

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...Hooks }
})
```

`"ex_money_input"` resolves because Phoenix's generated esbuild config puts `deps` on `NODE_PATH`, as it does for `"phoenix_html"`. If your build doesn't, import `"../../deps/ex_money_input/priv/static/money_input.js"` instead.

And in your CSS:

```css
@import "../../deps/ex_money_input/priv/static/money_input.css";
```

Without AutoNumeric loaded the inputs still work — only live formatting and cursor preservation are absent.

## Headless API

Three focused modules that need neither Phoenix nor Ecto. Parsing and formatting use `Money` and `Localize.Number` directly.

`Money.Input.Cast` turns a form-submission map, a string or a `Money` into a `t:Money.t/0`:

```elixir
iex> Money.Input.Cast.cast(%{"amount" => "1.234,56", "currency" => "EUR"}, locale: :de)
{:ok, Money.new(:EUR, "1234.56")}

iex> Money.Input.Cast.cast("$1,234.56", locale: :en)
{:ok, Money.new(:USD, "1234.56")}
```

`Money.Input.Validator` applies business rules — bounds, precision, required, currency match:

```elixir
iex> Money.Input.Validator.validate_money(Money.new(:USD, "1.50"), max: Money.new(:USD, 9999))
:ok

iex> Money.Input.Validator.validate_money(Money.new(:JPY, "1.5"))
{:error, %Money.Input.ValidationError{errors: [decimals: "must have at most 0 fractional digits"]}}
```

`Money.Input.Currency` returns the display data a component needs for a locale — separators, symbol, symbol position (derived from the CLDR currency format pattern) and currency precision:

```elixir
iex> {:ok, info} = Money.Input.Currency.currency_for_locale(:de, currency: :EUR)
iex> {info.decimal, info.symbol, info.symbol_position, info.iso_digits, info.number_system}
{",", "€", :suffix, 2, :latn}
```

Parsing a user-typed money string is `Money.parse/2`, which handles surrounding whitespace, accounting parentheses, and currency symbols and ISO codes:

```elixir
iex> Money.parse("$1,234.56")
Money.new(:USD, "1234.56")

iex> Money.parse("(1.234,56)", locale: :de, default_currency: :EUR)
Money.new(:EUR, "-1234.56")
```

Formatting is `Money.to_string/2`. Pass `currency_symbol: :none` for the amount alone, which is what a component renders into the input field (the space before `€` is a no-break space):

```elixir
iex> Money.to_string!(Money.new(:EUR, "1234.56"), locale: :de)
"1.234,56 €"

iex> Money.to_string!(Money.new(:EUR, "1234.56"), locale: :de, currency_symbol: :none)
"1.234,56"
```

## Ecto changeset

```elixir
def changeset(product, attrs) do
  product
  |> Ecto.Changeset.cast(attrs, [:price])
  |> Money.Input.Changeset.validate_money(:price,
    min: Money.new(:USD, "0.01"),
    max: Money.new(:USD, 9999)
  )
end
```

When the field isn't typed as `Money.Ecto.Composite.Type` (which casts the map shape automatically), use `Money.Input.Changeset.cast_money/3` first.

## Documentation

* **[Integration guide](https://hexdocs.pm/ex_money_input/integration.html)** — an end-to-end Phoenix walkthrough: Elixir and JS dependencies, asset wiring, schema and LiveView.

* **[Styling guide](https://hexdocs.pm/ex_money_input/styling.html)** — the DOM each component renders, the class names and CSS custom properties to target, and how to theme or replace the baseline stylesheet.

* **[Changelog](https://hexdocs.pm/ex_money_input/changelog.html)** — what changed in each release.

* **Playground** — [`money_input_playground`](https://github.com/ex-money/money_input_playground) is a Plug-based visualizer that demonstrates every component across CLDR locales and currencies. [A live instance](https://elixir-money-input.fly.dev) runs on Fly.io.

The full API reference is on [HexDocs](https://hexdocs.pm/ex_money_input).

## License

Money.Input is released under the Apache License 2.0. See [LICENSE.md](https://github.com/ex-money/money_input/blob/v0.3.1/LICENSE.md).
