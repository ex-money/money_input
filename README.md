# Money.Input

Locale-aware number and money form input — headless parser /
formatter / validator, Phoenix HEEx components (`<.number_input>`,
`<.money_input>`, `<.currency_picker>`), an AutoNumeric-backed JS
hook, and a Plug-based visualizer for local development.

For a full end-to-end Phoenix integration walkthrough — Elixir
deps, JS deps, asset wiring, schema, LiveView — read
[`guides/integration.md`](guides/integration.md).

## Installation

```elixir
def deps do
  [
    {:money_input, "~> 0.1.0"},
    # Optional — needed only for the components / visualizer:
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:ecto, "~> 3.10"},
    {:plug, "~> 1.15"},
    {:bandit, "~> 1.5"}
  ]
end
```

## Layered API

### 1. Headless (no Phoenix dependency)

```elixir
{:ok, %Decimal{} = decimal} = Money.Input.Parser.parse_number("1.234,56", locale: :de)
{:ok, %Money{} = money}     = Money.Input.Parser.parse_money("$1,234.56", locale: :en)

Money.Input.Formatter.format_number(decimal, locale: :en)             #=> "1,234.56"
Money.Input.Formatter.format_money(money,    locale: :de)             #=> "1.234,56 €"
Money.Input.Formatter.format_money(money,    locale: :en,
                                  no_symbol: true)                   #=> "1,234.56"

:ok = Money.Input.Validator.validate_money(Money.new(:USD, "1.50"))
{:error, [{:decimals, _}]} = Money.Input.Validator.validate_money(Money.new(:JPY, "1.5"))

{:ok, info} = Money.Input.Locale.resolve(:de, currency: :EUR)
info.decimal           #=> ","
info.group             #=> "."
info.symbol            #=> "€"
info.symbol_position   #=> :suffix
info.iso_digits        #=> 2
```

### 2. Ecto Changeset

```elixir
def changeset(product, attrs) do
  product
  |> Ecto.Changeset.cast(attrs, [:price, :quantity])
  |> Money.Input.Changeset.validate_money(:price,
       min: Money.new(:USD, "0.01"),
       max: Money.new(:USD, 9999))
  |> Money.Input.Changeset.validate_number(:quantity, min: 1)
end
```

### 3. HEEx components

```heex
<.number_input form={@form} field={:quantity} integer={true} min={1} max={999} />
<.number_input form={@form} field={:rating}   min={0} max={5} decimals={1} />

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

Without AutoNumeric loaded the inputs still work (Path A
fallback) — only live formatting and cursor preservation are
absent.

## Visualizer

```elixir
# In your dev config:
config :money_input, visualizer: true

# Standalone:
{:ok, _pid} = Money.Input.Visualizer.Standalone.start(port: 4002)
# Visit http://localhost:4002

# Or mount into Phoenix:
forward "/money-input", Money.Input.Visualizer
```

Views:

* `/input` — live HEEx renders of the actual components. Picks
  locale + currency, embeds the picker, mounts AutoNumeric from
  jsdelivr so the live behaviour is observable.
* `/parse` — one input × every locale (separator inversion,
  paste tolerance).
* `/format` — one parsed value × every locale.
* `/locale` — `Money.Input.Locale.resolve/2` snapshot per locale.

The standalone helper refuses to start unless the config flag is
set or `enabled: true` is passed explicitly, so a developer tool
can't deploy to production by accident.

## Out of scope (deliberate)

* Wise's bidirectional FX flow with live conversion — compose two
  `<.money_input>` components and wire your own rate provider.
* Scientific notation input — banking apps universally reject it
  (AutoNumeric does too).
* Keyboard increment/decrement — opt-in via AutoNumeric options
  if you need it.

## Architecture map

```
                       Localize.Number.Parser    Money.parse
                                  │                  │
                                  └────────┬─────────┘
                                           ▼
                       ┌────────────────────────────────┐
                       │ Money.Input.Parser              │  ← front door
                       │ Money.Input.Formatter           │
                       │ Money.Input.Validator           │
                       │ Money.Input.Locale              │
                       └────────────────────────────────┘
                                  │
                       ┌──────────┴──────────┐
                       ▼                     ▼
              Money.Input.Changeset    Money.Input.Components
              (Ecto)                  ─ number_input
                                      ─ money_input
                                      ─ currency_picker
                                           │
                                  priv/static/money_input.{js,css}
                                  (LiveView hooks, AutoNumeric wrapper)
```

## License

Apache-2.0.
