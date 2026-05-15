# Money.Input

Locale-aware money form input — `<.money_input>` and
`<.currency_picker>` Phoenix HEEx components, an
AutoNumeric-backed JS hook, an Ecto changeset bridge, and a
Plug-based visualizer for local development.

For a plain *number* input (no currency), see the sibling
[`localize_inputs`](https://hex.pm/packages/localize_inputs)
package — `<.number_input>` lives there.

For a full end-to-end Phoenix integration walkthrough — Elixir
deps, JS deps, asset wiring, schema, LiveView — read
[`guides/integration.md`](https://github.com/ex-money/money_input/blob/main/guides/integration.md).

## Installation

```elixir
def deps do
  [
    {:ex_money_input, "~> 0.1.0"},

    # Components and changeset bridge:
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:ecto, "~> 3.10"},

    # Visualizer (dev only):
    {:plug, "~> 1.15", only: :dev},
    {:bandit, "~> 1.5", only: :dev}
  ]
end
```

Every Phoenix/Ecto/Plug/Bandit dep is optional — the headless
layer compiles without any of them, and each higher layer
activates when its dep is present.

## Layered API

### 1. Headless (no Phoenix dependency)

Three focused modules. Parsing and formatting use `Money` and
`Localize.Number` directly — there are no wrappers here.

```elixir
# Cast — turn a form-submission *map*, a string, or a Money into a Money.t
{:ok, %Money{}} = Money.Input.Cast.cast(
  %{"amount" => "1.234,56", "currency" => "EUR"},
  locale: :de
)
{:ok, %Money{}} = Money.Input.Cast.cast("$1,234.56", locale: :en)

# Validator — apply *business rules* (bounds, precision, required, currency match)
:ok = Money.Input.Validator.validate_money(Money.new(:USD, "1.50"), max: Money.new(:USD, 9999))
{:error, [{:decimals, _}]} = Money.Input.Validator.validate_money(Money.new(:JPY, "1.5"))

# Currency — locale display data (separators, symbol position, currency precision)
{:ok, info} = Money.Input.Currency.currency_for_locale(:de, currency: :EUR)
info.decimal           #=> ","
info.symbol            #=> "€"
info.symbol_position   #=> :suffix  # derived from the CLDR currency format pattern
info.iso_digits        #=> 2
info.number_system     #=> :latn
```

**Parsing a user-typed money string is `Money.parse/2`**, which
already handles surrounding whitespace, accounting parens, and
currency symbols/ISO codes natively:

```elixir
%Money{} = Money.parse("$1,234.56")
%Money{} = Money.parse("(1.234,56)", locale: :de, default_currency: :EUR)
```

**Money formatting is `Money.to_string/2`** — pass
`currency_symbol: :none` for the amount alone (the shape a
component would render into the input field, with the symbol
positioned as a separate adornment):

```elixir
Money.to_string!(Money.new(:EUR, "1234.56"), locale: :de)
#=> "1.234,56 €"

Money.to_string!(Money.new(:EUR, "1234.56"), locale: :de, currency_symbol: :none)
#=> "1.234,56"
```

`Money.Input.Cast` vs `Money.Input.Validator`: **shape vs.
business rules**. Cast answers "can I parse this into a Money?".
Validator answers "is this Money acceptable under my app's
rules?".

### 2. Ecto Changeset

```elixir
def changeset(product, attrs) do
  product
  |> Ecto.Changeset.cast(attrs, [:price])
  |> Money.Input.Changeset.validate_money(:price,
       min: Money.new(:USD, "0.01"),
       max: Money.new(:USD, 9999))
end
```

When the field isn't typed as `Money.Ecto.Composite.Type` (which
casts the map shape automatically), use
`Money.Input.Changeset.cast_money/3` first.

### 3. HEEx components

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

Import them via `import Money.Input.Components` in your view or
`use` block.

The `<.money_input>` field always submits **two nested keys**,
whether the picker is on or not:

```
params["product"]["price"] = %{"amount" => "1234.56", "currency" => "USD"}
```

That shape is exactly what `Money.Ecto.Composite.Type.cast/1` and
`Money.Input.Changeset.cast_money/3` accept directly.

### 4. JS hook (AutoNumeric)

Add the peer dep:

```bash
npm install autonumeric
```

In `assets/js/app.js`:

```javascript
import AutoNumeric from "autonumeric"
import Hooks from "money_input"

Hooks.configure({ AutoNumeric })

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...Hooks }
})
```

And in your CSS:

```css
@import "money_input/priv/static/money_input.css";
```

Without AutoNumeric loaded the inputs still work — only live formatting and cursor preservation are
absent.

## Visualizer

```elixir
# In your dev config:
config :ex_money_input, visualizer: true

# Standalone:
{:ok, _pid} = Money.Input.Visualizer.Standalone.start(port: 4002)
# Visit http://localhost:4002

# Or mount into Phoenix:
forward "/money-input", Money.Input.Visualizer
```

Views:

* `/input` — live HEEx renders of the actual components. Picks locale + currency, embeds the picker, mounts AutoNumeric from jsdelivr so the live behaviour is observable.
* `/parse` — one input × every locale (separator inversion, paste tolerance).
* `/format` — one parsed value × every locale.
* `/locale` — `Money.Input.Currency.currency_for_locale/2` snapshot per locale.

The standalone helper refuses to start unless the config flag is set or `enabled: true` is passed explicitly, so a developer tool can't deploy to production by accident.

## License

Apache-2.0.
