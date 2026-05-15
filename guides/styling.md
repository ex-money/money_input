# Styling Money.Input

This guide is for anyone integrating `<.money_input>` or `<.currency_picker>` into an app whose look is already opinionated — Tailwind, DaisyUI, plain hand-written CSS, or a bespoke design system. It documents the DOM each component renders, the class names you can target, the CSS custom properties that drive the default theme, and the data attributes worth knowing about for state-driven styling.

The baseline stylesheet at `priv/static/money_input.css` is opt-in. You can import it, override its tokens, replace it entirely, or write Tailwind utilities against the class names below. Nothing in the components depends on a particular CSS framework.

---

## 1. Where the CSS lives

`money_input` ships one stylesheet:

```
priv/static/money_input.css
```

Pull it into your `assets/app.css`:

```css
@import "../../deps/money_input/priv/static/money_input.css";
```

…or copy it into your own assets and treat it as a starting point.

If you prefer not to ship the baseline at all (e.g. you'll write Tailwind utilities from scratch), every class name below is structural — the components will render exactly the same DOM with or without the stylesheet present. The unstyled result is a stack of `<div>` / `<input>` / `<button>` elements with no visual coherence; the components don't fall apart, they just won't look like anything.

---

## 2. Theming via CSS custom properties

The baseline reads from a small set of `--mi-*` tokens declared on `:root`. Override any of these in your own stylesheet to retheme without touching component rules:

| Token | Default | Purpose |
| --- | --- | --- |
| `--mi-border` | `#d4d4d8` | Wrapper + picker borders. |
| `--mi-border-focus` | `#047857` | Wrapper outline when an inner field has focus. |
| `--mi-bg` | `#ffffff` | Wrapper background, picker overlay background. |
| `--mi-bg-muted` | `#f5f5f4` | Currency symbol pill, picker trigger background. |
| `--mi-fg` | `#1c1917` | Foreground text. |
| `--mi-fg-muted` | `#78716c` | Secondary text — caret, code suffix, empty-state message. |
| `--mi-accent` | `#047857` | Selected-row background, search-input focus ring. |
| `--mi-accent-fg` | `#ecfdf5` | Foreground on the accent background (selected row). |
| `--mi-row-hover` | `#f0fdf4` | Row hover background in the picker. |
| `--mi-radius` | `0.375rem` | Wrapper + overlay corner radius. |
| `--mi-font` | `inherit` | Font family for inputs. |

Example — match a dark theme by redeclaring at the host-app level:

```css
:root {
  --mi-border: #3f3f46;
  --mi-border-focus: #34d399;
  --mi-bg: #18181b;
  --mi-bg-muted: #27272a;
  --mi-fg: #fafafa;
  --mi-fg-muted: #a1a1aa;
  --mi-accent: #10b981;
  --mi-accent-fg: #052e16;
  --mi-row-hover: rgba(255, 255, 255, 0.06);
}
```

Tokens are read at paint time, so a theme toggle that flips a `data-theme="dark"` attribute on `<html>` can simply redeclare them inside a `[data-theme="dark"]` selector.

---

## 3. `<.money_input>` DOM and classes

```heex
<.money_input form={@form} field={:price} currency={:USD} />
```

renders as (prefix-symbol locales, e.g. `en`):

```html
<div class="money-input-wrapper money-input-money"
     data-money-input="money"
     data-locale="en" data-currency="USD"
     data-decimal="." data-group="," data-minus="-"
     data-number-system="latn" data-iso-digits="2"
     data-symbol-position="prefix"
     data-min="" data-max=""
     phx-hook="MoneyInput"
     id="form_price-wrapper">
  <span class="money-input-symbol" aria-hidden="true">$</span>
  <input type="text"
         inputmode="decimal"
         name="form[price][amount]" id="form_price"
         value="1,234.50"
         class="money-input-field text-left"
         autocomplete="off" dir="ltr"
         aria-describedby="form_price-currency-name">
  <input type="hidden" name="form[price][currency]" value="USD">
  <span id="form_price-currency-name" class="sr-only">US Dollar</span>
</div>
```

For suffix-symbol locales (e.g. `fr`, `de`), the `<span class="money-input-symbol">` appears after the input. The CSS handles the border-side flip — see §6.

Classes you can target:

* `.money-input-wrapper` — outer flex container. Holds the border, radius, focus ring, and overflow clipping. Append your own via the `:class` attribute.

* `.money-input-money` — added alongside `.money-input-wrapper` whenever the component is a money input (as opposed to plain currency picker rendered on its own). Useful as a scoping selector when you also use `<.currency_picker>` standalone.

* `.money-input-field` — the `<input>` itself. Append via `:input_class`.

* `.money-input-symbol` — the currency symbol pill. Append via `:symbol_class`. Also used as the picker-trigger wrapper class when `currency_picker={true}`.

* `.text-left` / `.text-center` / `.text-right` — alignment, driven by `:align`. Applied to the input, not the wrapper.

* `.sr-only` — visually-hidden currency name announced by screen readers. Standard sr-only rules; don't override.

Data attributes for state-driven styling:

* `data-money-input="money"` — stable selector that survives class-list churn.

* `data-currency="USD"` — ISO 4217 code. Lets stylesheets attach currency-specific affordances (`[data-currency="JPY"] .money-input-field { /* … */ }`).

* `data-symbol-position="prefix" | "suffix"` — locale-derived. Useful if you want to flip padding asymmetrically by symbol side.

* `data-decimal` / `data-group` / `data-minus` / `data-number-system` / `data-iso-digits` — locale parameters the JS hook reads. Also handy if your stylesheet wants to render the decimal separator next to the input.

Focus ring: `.money-input-wrapper:focus-within` paints the border + outline. If you replace the rule, use `:focus-within` (not `:focus`) so the visual ring reacts to focus on the *child* input.

---

## 4. `<.currency_picker>` DOM and classes

When used inline as `<.money_input currency_picker={true}>`, the picker replaces the `.money-input-symbol` pill. As a standalone `<.currency_picker>` it renders the same DOM unwrapped:

```html
<div class="currency-picker"
     data-currency-picker
     data-locale="en"
     data-current="USD"
     data-variant="auto"
     data-recents-limit="5"
     data-preferred="USD,EUR,GBP"
     phx-hook="CurrencyPicker">

  <button class="currency-picker-trigger"
          data-currency-picker-trigger
          aria-haspopup="listbox" aria-expanded="false">
    <span class="currency-picker-flag" aria-hidden="true">🇺🇸</span>
    <span class="currency-picker-code">USD</span>
    <span class="currency-picker-caret" aria-hidden="true">▾</span>
  </button>

  <input type="hidden" name="form[currency]" value="USD"
         data-currency-picker-value>

  <div class="currency-picker-overlay" data-currency-picker-overlay
       role="dialog" aria-label="Choose currency" hidden>
    <div class="currency-picker-search-row">
      <input type="search" class="currency-picker-search"
             data-currency-picker-search
             placeholder="Search code, name, country, symbol…">
      <button class="currency-picker-close"
              data-currency-picker-close>×</button>
    </div>
    <ul class="currency-picker-list" role="listbox" data-currency-picker-list>
      <li class="currency-picker-section">Recent</li>
      <li class="currency-picker-row" role="option" tabindex="-1"
          data-currency-picker-row
          data-code="USD" data-name="US Dollar"
          data-country="United States" data-symbol="$"
          data-iso-digits="2"
          aria-selected="true">
        <span class="currency-picker-flag" aria-hidden="true">🇺🇸</span>
        <span class="currency-picker-row-code">USD</span>
        <span class="currency-picker-row-name">US Dollar</span>
        <span class="currency-picker-row-symbol">$</span>
      </li>
      …
      <li class="currency-picker-section">Preferred</li>
      …
      <li class="currency-picker-section">All currencies</li>
      …
      <li class="currency-picker-empty" data-currency-picker-empty hidden>No matches</li>
    </ul>
  </div>
</div>
```

Classes you can target:

| Class | What it is |
| --- | --- |
| `.currency-picker` | Outer positioning container (relative). Add via `:class`. |
| `.currency-picker-trigger` | The button users click to open the overlay. Add via `:button_class`. |
| `.currency-picker-flag` | The flag emoji span. Used both in the trigger and inside each row. |
| `.currency-picker-code` | The visible ISO code in the trigger (e.g. `USD`). |
| `.currency-picker-caret` | The little `▾` indicator. |
| `.currency-picker-overlay` | The floating panel. Add via `:overlay_class`. |
| `.currency-picker-search-row` | Wraps the search input + close button. |
| `.currency-picker-search` | The filter `<input type="search">`. |
| `.currency-picker-close` | The × dismiss button. |
| `.currency-picker-list` | The `<ul role="listbox">`. |
| `.currency-picker-section` | The "Recent" / "Preferred" / "All currencies" group heading. |
| `.currency-picker-row` | A selectable row. Add via `:row_class`. |
| `.currency-picker-row-code` | The 3-letter ISO code inside a row. |
| `.currency-picker-row-name` | The localized currency name. |
| `.currency-picker-row-symbol` | The currency symbol (e.g. `$`). |
| `.currency-picker-empty` | Shown when the search filters down to zero rows. |

State selectors that matter:

* `.currency-picker-row[aria-selected="true"]` — the currently-chosen currency. Painted with `--mi-accent` by default.

* `.currency-picker-row:focus` — keyboard-arrow focus. Distinct outline ring; never collapses with `:hover` or `[aria-selected]`.

* `.currency-picker-trigger[aria-expanded="true"]` — set while the overlay is open. Useful if you want the trigger to flatten its bottom border when the dropdown is visible.

* `.currency-picker.is-sheet` — applied when the picker is rendered as a full-screen mobile sheet (see §5).

* `.currency-picker-overlay[hidden]` — the overlay is shown/hidden via the `hidden` attribute, not a class. `[hidden]` already produces `display: none` in user-agent stylesheets, so you almost never need to write rules against this directly.

Data attributes worth styling against:

* `data-variant="dropdown" | "sheet" | "auto"` — set on the outer `.currency-picker`. Forces the variant explicitly (the auto-variant adds `.is-sheet` at runtime based on viewport width).

* `data-current="..."` — the canonical ISO code on the outer wrapper.

* `data-code="..."` / `data-country="..."` / `data-symbol="..."` / `data-iso-digits="..."` — on each row. Lets you write rules like `[data-iso-digits="0"] .currency-picker-row-name::after { content: " (no fractional unit)"; }`.

* `data-recents-limit="..."` / `data-preferred="..."` — read by the JS hook, but also fair game for CSS-attribute selectors.

---

## 5. Mobile sheet variant

By default, the picker overlay floats as a 22 rem dropdown anchored to the trigger. Below 600 px viewport width, the JS hook adds `.is-sheet` to the wrapper and the overlay becomes a full-screen modal sliding up from the bottom:

```css
.currency-picker.is-sheet .currency-picker-overlay {
  position: fixed;
  inset: 0;
  width: 100vw;
  max-width: 100vw;
  max-height: 100vh;
  border-radius: 0;
  z-index: 100;
  animation: mi-sheet-slide-in 200ms ease-out;
}
.currency-picker.is-sheet .currency-picker-row { padding: 0.85rem 1rem; }
```

You can force the sheet variant on any viewport by setting `variant={:sheet}` on the component. To disable the sheet entirely and keep the dropdown layout on mobile, pass `variant={:dropdown}`.

The slide-in animation is suppressed under `@media (prefers-reduced-motion: reduce)`. Any custom animation you add should follow the same pattern.

---

## 6. Currency-symbol position quirks

Locales differ on whether the currency symbol prefixes (`$1,234.50`) or suffixes (`1.234,50 €`) the amount. The component renders the `<span class="money-input-symbol">` (or `<.currency_picker>`) on the appropriate side based on the locale, and the CSS handles the border:

```css
.money-input-symbol {
  border-right: 1px solid var(--mi-border);
}
.money-input-wrapper > .money-input-symbol:last-child {
  border-right: 0;
  border-left: 1px solid var(--mi-border);
}
```

If you replace the stylesheet, replicate the `:last-child` rule — otherwise suffix-locale symbols will have a stray right-border and no left-border.

The actual position is exposed via the wrapper's `data-symbol-position="prefix" | "suffix"` attribute. Use it for any layout-sensitive overrides you need.

---

## 7. Approach 1: keep the baseline, override tokens

The cheapest integration. Import `money_input.css`, redeclare the `--mi-*` tokens to match your palette, done:

```css
@import "../../deps/money_input/priv/static/money_input.css";

:root {
  --mi-border: theme("colors.zinc.300");
  --mi-border-focus: theme("colors.indigo.600");
  --mi-accent: theme("colors.indigo.600");
  --mi-radius: 0.5rem;
}
```

This is enough to integrate with most design systems without writing component-level rules.

---

## 8. Approach 2: Tailwind utilities via attributes

Pass utility strings directly on each component. The attributes are `:class`, `:input_class`, `:symbol_class`, `:button_class`, `:overlay_class`, `:row_class`. They're appended to the structural class lists, so you can either add to or override the baseline:

```heex
<.money_input
  form={@form}
  field={:price}
  currency={:USD}
  class="rounded-xl border-2 border-indigo-200 focus-within:border-indigo-600 focus-within:outline-indigo-600"
  input_class="px-4 py-3 text-lg"
  symbol_class="bg-indigo-50 text-indigo-900 font-semibold"
/>
```

If you want to suppress the baseline entirely, don't import `money_input.css`. The structural class names still appear in the DOM so `@apply`-style rules against `.money-input-wrapper` keep working — they just have nothing to override.

---

## 9. Approach 3: replace the stylesheet wholesale

Copy `priv/static/money_input.css` into your assets and edit freely. The component DOM is stable across releases: class names, data attributes, and nesting are part of the public contract. Treat structural names as documented selectors; treat the baseline rules as starter content.

If you fork the stylesheet, you can still benefit from the `--mi-*` tokens by leaving them in place — third-party plugins that target Money.Input will pick them up too.

---

## 10. Accessibility hooks

A few selectors exist specifically for assistive tech and shouldn't be styled away:

* `[role="listbox"]` on `.currency-picker-list` — screen readers announce the list as a single composite widget.

* `[role="option"]` + `aria-selected` on `.currency-picker-row` — drives "selected" announcements.

* `[aria-haspopup="listbox"]` + `aria-expanded` on `.currency-picker-trigger` — announces "menu, collapsed/expanded".

* `aria-label` strings on the search input, close button, and overlay — extracted to gettext, so they localize automatically.

* `aria-describedby` on the amount `<input>` points at a visually-hidden `<span class="sr-only">` carrying the localized currency name. Screen readers announce "1,234.50 US Dollar" rather than "1,234.50 dollar sign".

* `dir="ltr"` is forced on the numeric `<input>` even under RTL locales. The number grammar (decimal separator, grouping) is LTR even when the surrounding page is RTL. The wrapper inherits the page's `dir`, so labels, captions, and adjacent help text flip correctly.

The structural styles assume `box-sizing: border-box` is in effect (the modern default in nearly every reset). If your reset deviates, expect the picker's grid template (`grid-template-columns: 1.5rem 3rem 1fr auto;` on rows) to need adjustment.

---

## 11. Quick reference: every public class name

```
money-input-wrapper
money-input-money
money-input-field
money-input-symbol
text-left | text-center | text-right
sr-only

currency-picker
currency-picker.is-sheet
currency-picker-trigger
currency-picker-flag
currency-picker-code
currency-picker-caret
currency-picker-overlay
currency-picker-search-row
currency-picker-search
currency-picker-close
currency-picker-list
currency-picker-section
currency-picker-row
currency-picker-row-code
currency-picker-row-name
currency-picker-row-symbol
currency-picker-empty
```

And every data attribute used as a styling/scripting hook:

```
data-money-input="money"              (on .money-input-wrapper)
data-currency="..."                   (on .money-input-wrapper)
data-symbol-position="prefix|suffix"  (on .money-input-wrapper)
data-currency-picker                  (on .currency-picker)
data-currency-picker-trigger          (on .currency-picker-trigger)
data-currency-picker-overlay          (on .currency-picker-overlay)
data-currency-picker-search           (on .currency-picker-search)
data-currency-picker-close            (on .currency-picker-close)
data-currency-picker-list             (on .currency-picker-list)
data-currency-picker-row              (on .currency-picker-row)
data-currency-picker-value            (on the hidden value input)
data-currency-picker-empty            (on .currency-picker-empty)
data-variant="auto|dropdown|sheet"    (on .currency-picker)
data-current="..."                    (on .currency-picker)
data-recents-limit="..."              (on .currency-picker)
data-preferred="..."                  (on .currency-picker)
data-code / data-name / data-country
  data-symbol / data-iso-digits       (on .currency-picker-row)
```

If you find yourself reaching for an undocumented internal class or attribute, open an issue — those are non-public and may change between releases.
