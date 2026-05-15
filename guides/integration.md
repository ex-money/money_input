# Integrating Money.Input into a Phoenix app

This guide walks through adding `money_input` to an existing
Phoenix 1.7+ / LiveView 1.0+ project, end-to-end: Elixir deps,
JavaScript deps, asset wiring, a schema with a Money field, a
LiveView using the components, and a quick smoke test.

If you only need the headless parser / formatter / validator (no
Phoenix), skip to [Headless API](#headless-api-no-phoenix) at the
bottom.

---

## 1. Elixir dependencies

Add the package and its optional partners to `mix.exs`. Only the
first line is strictly required; the others are pulled in
automatically by a Phoenix project but listed here for clarity.

```elixir
def deps do
  [
    {:money_input, "~> 0.1.0"},

    # The components are activated when these are present:
    {:phoenix_html,        "~> 4.0"},
    {:phoenix_live_view,   "~> 1.0"},

    # The changeset helper activates when this is present:
    {:ecto,                "~> 3.10"},

    # The visualizer activates when these are present:
    {:plug,                "~> 1.15", only: :dev},
    {:bandit,              "~> 1.5",  only: :dev}
  ]
end
```

Run `mix deps.get`.

> Each optional dep is gated by `Code.ensure_loaded?/1`, so the
> headless layer compiles cleanly without any of them. You won't
> get "missing module" warnings.

---

## 2. JavaScript dependencies

The live-formatting JS hook wraps
[AutoNumeric](https://autonumeric.org/) (battle-tested cursor
preservation, paste sanitisation, per-locale separators). Install
it in your `assets/` directory:

```bash
cd assets
npm install autonumeric
```

> AutoNumeric is **~50 KB minified, gzipped**. If you object to
> that and prefer the Path A fallback (server-side blur
> formatting, no live formatting), skip this step — the
> components still work, you just don't get cursor-preserving
> live formatting.

---

## 3. Wire the JS hooks into `app.js`

In `assets/js/app.js`:

```javascript
import {Socket}    from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import AutoNumeric from "autonumeric"
import MoneyHooks  from "money_input"

// Tell the hooks where to find AutoNumeric. If you skip this
// the hooks degrade to the Path A baseline (no live formatting).
MoneyHooks.configure({ AutoNumeric })

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    NumberInput:    MoneyHooks.NumberInput,
    MoneyInput:     MoneyHooks.MoneyInput,
    CurrencyPicker: MoneyHooks.CurrencyPicker
  }
})

liveSocket.connect()
window.liveSocket = liveSocket
```

The `money_input` package ships ESM. Most projects already have
`esbuild` configured to pull `node_modules` resolution — if yours
doesn't, point esbuild at the file path:

```javascript
import MoneyHooks from "../../deps/money_input/priv/static/money_input.js"
```

---

## 4. Wire the CSS

The components ship a small CSS file with sensible defaults
(uses CSS custom properties — easy to theme). Import it in
`assets/css/app.css`:

```css
@import "../../deps/money_input/priv/static/money_input.css";
```

The file defines `--mi-border`, `--mi-accent`, `--mi-radius` etc.
Override these in your own stylesheet to match your design
system. The components emit semantic class names
(`money-input-wrapper`, `currency-picker-trigger`, …) so a
Tailwind project can also rebuild the styles from scratch.

---

## 5. Configure your schema

For an `Ecto` schema with a money field, use the existing
`Money.Ecto.Composite.Type` (from `money_sql`) — it accepts
exactly the `%{"amount" => ..., "currency" => ...}` map shape
that `<.money_input>` submits, so casting is one line.

```elixir
defmodule MyApp.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name,     :string
    field :price,    Money.Ecto.Composite.Type
    field :quantity, :integer
    field :rating,   :decimal

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price, :quantity, :rating])
    |> validate_required([:name, :price])
    |> Money.Input.Changeset.validate_money(:price,
         min: Money.new(:USD, "0.01"),
         max: Money.new(:USD, 9999))
    |> Money.Input.Changeset.validate_number(:quantity, min: 1, max: 999)
    |> Money.Input.Changeset.validate_number(:rating,   min: 0, max: 5, decimals: 1)
  end
end
```

`Money.Input.Changeset.validate_money/3` wraps
`Money.Input.Validator.validate_money/2` — currency-aware
precision (USD: 2, JPY: 0, BHD: 3), `:min`/`:max`/`:currency`/
`:required` options.

### If your field isn't typed as `Money.Ecto.Composite.Type`

For a `:map` field (or any non-composite typing), use
`cast_money/3` instead to parse the submitted map into a
`Money.t/0`:

```elixir
def changeset(product, attrs, locale) do
  product
  |> cast(attrs, [:name])
  |> Money.Input.Changeset.cast_money(:price, locale: locale, currency: :USD)
  |> Money.Input.Changeset.validate_money(:price, min: Money.new(:USD, "0.01"))
end
```

`cast_money/3` delegates to `Money.Input.Cast.cast/2`, which
uses `Money.new/3` with the locale option for map shapes and
`Money.parse/2` for bare strings — locale-formatted amounts
work whether or not the JS hook is loaded.

---

## 6. Render the components in a LiveView

```elixir
defmodule MyAppWeb.ProductFormLive do
  use MyAppWeb, :live_view
  import Money.Input.Components

  alias MyApp.Catalog.{Product, Products}

  def mount(_params, _session, socket) do
    changeset = Products.change_product(%Product{})
    {:ok, assign(socket, form: to_form(changeset))}
  end

  def handle_event("validate", %{"product" => attrs}, socket) do
    changeset =
      %Product{}
      |> Products.change_product(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"product" => attrs}, socket) do
    case Products.create_product(attrs) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate" phx-submit="save">
      <.input field={@form[:name]} label="Name" />

      <.money_input
        form={@form}
        field={:price}
        default_currency={:USD}
        currency_picker={true}
        preferred_currencies={[:USD, :EUR, :GBP, :JPY]}
      />

      <.number_input form={@form} field={:quantity} integer={true} min={1} max={999} />
      <.number_input form={@form} field={:rating}   min={0} max={5} decimals={1} />

      <button type="submit">Save</button>
    </.form>
    """
  end
end
```

---

## 7. What gets submitted

The `<.money_input>` field always submits **two nested keys**,
regardless of whether the picker is on:

```
params["product"] = %{
  "price" => %{
    "amount"   => "1.234,56",   # locale-formatted as the user typed
    "currency" => "USD"         # picker selection or fixed attr
  },
  "quantity" => "5",
  "rating"   => "4.5"
}
```

This shape is what `Money.Ecto.Composite.Type.cast/1` and
`Money.Input.Changeset.cast_money/3` both accept directly. No
custom param-flattening required.

**The amount is whatever the user typed**, locale-formatted, on
both Path A (no JS) and Path B (AutoNumeric loaded). The server
parses it using the locale you pass to `cast_money/3` or the
locale embedded in the `Money.Ecto.Composite.Type` field
options. There's no canonical-vs-locale ambiguity on the wire —
one shape, parsed once.

---

## 8. Enable the dev visualizer (optional)

The visualizer is a Plug.Router that demos every component +
locale + currency combination, with the JS hooks bootstrapped
from a CDN. Useful for quickly checking how a locale formats or
what the picker looks like.

In `config/dev.exs`:

```elixir
config :money_input, visualizer: true
config :localize,    allow_runtime_locale_download: true
```

Then either mount it inside your Phoenix router…

```elixir
# in lib/my_app_web/router.ex
if Mix.env() == :dev do
  forward "/money-input", Money.Input.Visualizer
end
```

…or run it standalone in an IEx session:

```elixir
{:ok, _pid} = Money.Input.Visualizer.Standalone.start(port: 4002)
# Visit http://localhost:4002
```

The standalone helper refuses to boot unless the config flag is
on, so it can't accidentally ship to production.

---

## 9. Smoke test

A quick LiveViewTest that verifies the form round-trips:

```elixir
defmodule MyAppWeb.ProductFormLiveTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "submits price as nested amount + currency", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products/new")

    view
    |> form("#product-form", product: %{
        name: "Widget",
        price: %{amount: "12.34", currency: "EUR"},
        quantity: "5"
      })
    |> render_submit()

    assert MyApp.Catalog.list_products() |> hd() |> Map.fetch!(:price) ==
             Money.new(:EUR, "12.34")
  end
end
```

---

## Headless API (no Phoenix)

If you don't need the components, the package's cast/validate/
locale modules work standalone. Parsing and formatting use
`Money` directly — there are no wrappers:

```elixir
%Money{} = money = Money.parse("$1,234.56")
%Money{} = Money.parse("1.234,56", locale: :de, default_currency: :EUR)

{:ok, money} = Money.Input.Cast.cast(%{"amount" => "1234.56", "currency" => "USD"})

Money.to_string!(money, locale: :de)
#=> "1.234,56 $"

:ok = Money.Input.Validator.validate_money(money, max: Money.new(:USD, 9999))

{:ok, info} = Money.Input.Locale.resolve(:de, currency: :EUR)
info.decimal           #=> ","
info.symbol_position   #=> :suffix
```

No Phoenix, no Ecto, no JS — just the locale-aware data layer.

---

## Troubleshooting

**The picker opens, but the overlay shows behind another element.**
The overlay uses `z-index: 20`. If your app has elements at
higher z-indexes, bump `--mi-overlay-z` (or override the
`.currency-picker-overlay` rule directly).

**AutoNumeric isn't formatting.** Check the browser console: you
should see no errors and the input should have an `autonumeric`
class added by AutoNumeric. If neither, confirm
`MoneyHooks.configure({ AutoNumeric })` runs **before**
`new LiveSocket(...)`.

**`Money.Ecto.Composite.Type` not found.** This type is in
`money_sql`, a separate package — add `{:money_sql, "~> 1.0"}`
to deps and run `mix deps.get`.

**The server receives an unparsable amount in dev.** Make sure
`config :localize, allow_runtime_locale_download: true` is set
in `config/dev.exs` if the user is on a locale that wasn't
pre-compiled into your build.

**My visualizer shows `nil` for some locales.** Same fix — set
`allow_runtime_locale_download` so CLDR data is fetched on
demand.
