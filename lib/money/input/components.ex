if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Money.Input.Components do
    @moduledoc """
    HEEx components for locale-aware money input.

    Two components ship from this module:

    * `money_input/1` — money input with a fixed currency or an
      embedded `currency_picker/1`.
    * `currency_picker/1` — first-class searchable currency picker
      (flag glyphs, recents in `localStorage`, mobile sheet
      variant, keyboard nav).

    Both render their HTML baseline server-side and degrade
    gracefully when JS is disabled. With the JS hook loaded
    (`priv/static/money_input.js`), they upgrade to live
    formatting and full picker behaviour.

    For a plain *number* input (no currency), use
    [`Localize.Inputs.Components.number_input/1`](https://hexdocs.pm/localize_inputs)
    from the sibling `localize_inputs` package.

    ## Setup

    Add the JS hooks in your `assets/js/app.js`:

        import { MoneyInput, CurrencyPicker } from "money_input"
        let Hooks = {}
        Hooks.MoneyInput = MoneyInput
        Hooks.CurrencyPicker = CurrencyPicker

    And install the AutoNumeric peer dep:

        npm install autonumeric

    See `Money.Input` for a full feature overview.

    """

    use Phoenix.Component

    alias Money.Input.Currency
    alias Money.Input.Components.Flags

    @doc """
    Locale-aware money input.

    Returns `Money.t/0` on form submission. Renders the currency
    symbol as an adornment outside the input — the user only
    types digits and a decimal separator.

    With `currency_picker={true}`, embeds the bundled
    `currency_picker/1` in the symbol-adornment position so the
    user can switch currencies. Currency-aware precision: USD
    accepts 2 decimals, JPY 0, BHD 3.

    ### Attributes

    * `:default_currency` — the currency used when the form value
      doesn't carry one and the user hasn't (yet) picked one. With
      the picker off this is the only currency the field accepts.
      With the picker on it pre-selects the trigger and acts as
      the fallback when the form value is blank.

    ### Examples

        <.money_input form={@form} field={:price} default_currency={:USD} />

        <.money_input
          form={@form}
          field={:price}
          default_currency={:USD}
          currency_picker={true}
          preferred_currencies={[:USD, :EUR, :GBP]}
        />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:value, :any, default: nil)
    attr(:locale, :string, default: nil)

    attr(:default_currency, :atom,
      default: nil,
      doc: "The currency used when the form value doesn't carry one. Pre-selects the picker."
    )

    attr(:currency_field, :atom, default: nil)

    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:align, :atom, default: :right, values: [:left, :right, :center])
    attr(:placeholder, :string, default: nil)
    attr(:symbol_position, :atom, default: :auto, values: [:auto, :prefix, :suffix])
    attr(:symbol_kind, :atom, default: :symbol, values: [:symbol, :iso, :narrow, :none])
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:symbol_class, :string, default: nil)

    attr(:currency_picker, :boolean, default: false)
    attr(:allowed_currencies, :list, default: nil)
    attr(:preferred_currencies, :list, default: [])
    attr(:rest, :global, include: ~w(disabled readonly required autofocus))

    def money_input(assigns) do
      assigns =
        assigns
        |> assign_money_field_names()
        |> assign_money_value()
        |> assign_money_locale_data()
        |> assign_symbol_position()

      ~H"""
      <div
        class={["money-input-wrapper", "money-input-money", @class]}
        data-money-input="money"
        data-locale={@locale_data.locale}
        data-currency={@effective_currency && to_string(@effective_currency)}
        data-decimal={@locale_data.decimal}
        data-group={@locale_data.group}
        data-number-system={@locale_data.number_system}
        data-minus={@locale_data.minus_sign}
        data-iso-digits={@locale_data.iso_digits}
        data-symbol-position={@symbol_position}
        data-min={value_attr(@min)}
        data-max={value_attr(@max)}
        phx-hook={if @js, do: "MoneyInput"}
        id={"#{@amount_id}-wrapper"}
      >
        <.money_adornment
          :if={@symbol_position == :prefix}
          symbol={@locale_data.symbol}
          symbol_class={@symbol_class}
          currency_picker={@currency_picker}
          currency={@effective_currency}
          locale={@locale_data.locale}
          allowed_currencies={@allowed_currencies}
          preferred_currencies={@preferred_currencies}
          currency_name={@currency_name}
          currency_id={@currency_id}
          id={"#{@amount_id}-symbol"}
        />
        <input
          type="text"
          inputmode="decimal"
          name={@amount_name}
          id={@amount_id}
          value={@formatted_value}
          class={["money-input-field", text_align_class(@align), @input_class]}
          autocomplete="off"
          dir="ltr"
          placeholder={@placeholder}
          aria-describedby={"#{@amount_id}-currency-name"}
          {@rest}
        />
        <%!-- When the picker is off, the currency travels alongside
              the amount as a hidden sibling. The server receives
              `params[field] = %{"amount" => ..., "currency" => ...}`
              either way, so `Money.Ecto.Composite.Type` and
              `Money.Input.Changeset.cast_money/3` cast in one step. --%>
        <input
          :if={!@currency_picker}
          type="hidden"
          name={@currency_name}
          id={@currency_id}
          value={@effective_currency && to_string(@effective_currency)}
        />
        <.money_adornment
          :if={@symbol_position == :suffix}
          symbol={@locale_data.symbol}
          symbol_class={@symbol_class}
          currency_picker={@currency_picker}
          currency={@effective_currency}
          locale={@locale_data.locale}
          allowed_currencies={@allowed_currencies}
          preferred_currencies={@preferred_currencies}
          currency_name={@currency_name}
          currency_id={@currency_id}
          id={"#{@amount_id}-symbol"}
        />
        <span id={"#{@amount_id}-currency-name"} class="sr-only">
          {currency_name(@locale_data.currency, @locale_data.locale)}
        </span>
      </div>
      """
    end

    attr(:symbol, :string, default: nil)
    attr(:symbol_class, :string, default: nil)
    attr(:currency_picker, :boolean, default: false)
    attr(:currency, :atom, default: nil)
    attr(:locale, :any, default: nil)
    attr(:allowed_currencies, :list, default: nil)
    attr(:preferred_currencies, :list, default: [])
    attr(:currency_name, :string, default: nil)
    attr(:currency_id, :string, default: nil)
    attr(:id, :string, required: true)

    defp money_adornment(assigns) do
      ~H"""
      <%= if @currency_picker do %>
        <.currency_picker
          name={@currency_name}
          input_id={@currency_id}
          current={@currency}
          allowed={@allowed_currencies}
          preferred={@preferred_currencies}
          locale={@locale}
          id={@id}
          class={Enum.join(["money-input-symbol", @symbol_class || ""], " ")}
        />
      <% else %>
        <span
          class={["money-input-symbol", @symbol_class]}
          aria-hidden="true"
        >{@symbol}</span>
      <% end %>
      """
    end

    @doc """
    First-class searchable currency picker.

    Renders as a trigger button (flag + ISO code). Clicking opens
    an overlay with a search input, recent selections (persisted
    in `localStorage`), pinned preferred currencies, and the full
    sorted currency list. On mobile, the overlay becomes a
    full-screen sheet.

    ### Examples

        <.currency_picker
          form={@form}
          field={:currency}
          current={:USD}
          preferred={[:USD, :EUR, :GBP, :JPY]}
        />

    """
    attr(:form, Phoenix.HTML.Form, default: nil)
    attr(:field, :atom, default: nil)

    attr(:name, :string,
      default: nil,
      doc:
        "Explicit hidden-input name. Overrides form+field. Used by `money_input/1` to inject a nested name like `price[currency]`."
    )

    attr(:input_id, :string,
      default: nil,
      doc: "Explicit id for the hidden value input."
    )

    attr(:current, :atom, required: true)
    attr(:allowed, :list, default: nil)
    attr(:preferred, :list, default: [])
    attr(:recents_limit, :integer, default: 5)
    attr(:locale, :any, default: nil)
    attr(:variant, :atom, default: :auto, values: [:auto, :dropdown, :sheet])
    attr(:id, :string, default: nil)
    attr(:class, :string, default: nil)
    attr(:button_class, :string, default: nil)
    attr(:overlay_class, :string, default: nil)
    attr(:row_class, :string, default: nil)

    def currency_picker(assigns) do
      assigns = assign_picker(assigns)

      ~H"""
      <div
        class={["currency-picker", @class]}
        id={@id}
        data-currency-picker
        data-locale={@locale_id}
        data-current={to_string(@current)}
        data-variant={to_string(@variant)}
        data-recents-limit={@recents_limit}
        data-preferred={Enum.map_join(@preferred, ",", &to_string/1)}
        phx-hook="CurrencyPicker"
      >
        <button
          type="button"
          class={["currency-picker-trigger", @button_class]}
          data-currency-picker-trigger
          aria-haspopup="listbox"
          aria-expanded="false"
        >
          <span class="currency-picker-flag" aria-hidden="true">{flag_for(@current)}</span>
          <span class="currency-picker-code">{@current}</span>
          <span class="currency-picker-caret" aria-hidden="true">▾</span>
        </button>
        <%= if @hidden_name do %>
          <input
            type="hidden"
            name={@hidden_name}
            id={@hidden_id}
            value={to_string(@current)}
            data-currency-picker-value
          />
        <% end %>
        <div
          class={["currency-picker-overlay", @overlay_class]}
          data-currency-picker-overlay
          role="dialog"
          aria-label="Choose currency"
          hidden
        >
          <div class="currency-picker-search-row">
            <input
              type="search"
              class="currency-picker-search"
              data-currency-picker-search
              placeholder="Search code, name, country, symbol…"
              aria-label="Filter currencies"
            />
            <button
              type="button"
              class="currency-picker-close"
              data-currency-picker-close
              aria-label="Close currency picker"
            >×</button>
          </div>
          <ul class="currency-picker-list" role="listbox" data-currency-picker-list>
            <%= for {section_label, rows} <- @sections do %>
              <%= if rows != [] do %>
                <li class="currency-picker-section" role="presentation">{section_label}</li>
                <%= for row <- rows do %>
                  <li
                    class={["currency-picker-row", @row_class]}
                    role="option"
                    tabindex="-1"
                    data-currency-picker-row
                    data-code={row.code}
                    data-name={row.name}
                    data-country={row.country}
                    data-symbol={row.symbol}
                    data-iso-digits={row.iso_digits}
                    aria-selected={if row.code == to_string(@current), do: "true"}
                  >
                    <span class="currency-picker-flag" aria-hidden="true">{row.flag}</span>
                    <span class="currency-picker-row-code">{row.code}</span>
                    <span class="currency-picker-row-name">{row.name}</span>
                    <span class="currency-picker-row-symbol">{row.symbol}</span>
                  </li>
                <% end %>
              <% end %>
            <% end %>
            <li class="currency-picker-empty" data-currency-picker-empty hidden>No matches</li>
          </ul>
        </div>
      </div>
      """
    end

    # ── Internal: shared assigns ──────────────────────────────

    defp assign_money_value(assigns) do
      explicit = assigns.value
      form_value = (assigns.form[assigns.field] || %{}).value
      raw = explicit || form_value

      {amount, currency_from_value} = extract_amount_and_currency(raw)
      effective_currency = currency_from_value || assigns.default_currency

      formatted = format_amount(amount, effective_currency, assigns.locale)

      assigns
      |> assign(:formatted_value, formatted)
      |> assign(:effective_currency, effective_currency)
    end

    # Format the amount portion only (no currency symbol) for the
    # input's `value` attribute. The symbol is rendered as a
    # separate adornment outside the input. `Money.to_string!`
    # with `currency_symbol: :none` does the locale-correct
    # rendering — separators, spacing, and currency-aware
    # fractional digits (JPY 0, USD 2, BHD 3).
    #
    # `Money.new/3` itself needs the locale to parse a
    # locale-formatted amount string (Path A fallback path) —
    # without it, `"1.234,56"` is read as `"1.23456"`.
    defp format_amount(nil, _currency, _locale), do: ""
    defp format_amount("", _currency, _locale), do: ""
    defp format_amount(_amount, nil, _locale), do: ""

    defp format_amount(amount, currency, locale) do
      case Money.new(currency, amount, locale: locale) do
        %Money{} = money ->
          Money.to_string!(money, locale: locale, currency_symbol: :none)

        # Unparseable amount (non-empty garbage like "abc"). Render
        # the input as blank — the surrounding template still keeps
        # the user's raw text in the actual form, so they can
        # correct it. Better than crashing the whole page.
        {:error, _} ->
          ""
      end
    end

    # money_input receives values in four shapes; we normalise to
    # `{amount, currency}` so the rest of the render path doesn't
    # have to branch.
    defp extract_amount_and_currency(nil), do: {nil, nil}
    defp extract_amount_and_currency(""), do: {nil, nil}
    defp extract_amount_and_currency(%Money{} = m), do: {m.amount, m.currency}
    defp extract_amount_and_currency(%Decimal{} = d), do: {d, nil}
    defp extract_amount_and_currency(v) when is_integer(v) or is_float(v), do: {v, nil}

    defp extract_amount_and_currency(%{} = map) do
      amount =
        map["amount"] || map[:amount] ||
          Map.get(map, "amount") || Map.get(map, :amount)

      currency =
        normalize_currency_code(
          map["currency"] || map[:currency] ||
            Map.get(map, "currency") || Map.get(map, :currency)
        )

      {amount, currency}
    end

    defp extract_amount_and_currency(value) when is_binary(value), do: {value, nil}
    defp extract_amount_and_currency(_), do: {nil, nil}

    defp normalize_currency_code(nil), do: nil
    defp normalize_currency_code(code) when is_atom(code), do: code

    defp normalize_currency_code(code) when is_binary(code) do
      try do
        String.to_existing_atom(String.upcase(code))
      rescue
        _ -> nil
      end
    end

    defp assign_money_field_names(assigns) do
      field_struct = assigns.form[assigns.field]
      base_name = field_struct.name
      base_id = field_struct.id

      assigns
      |> assign(:amount_name, "#{base_name}[amount]")
      |> assign(:currency_name, "#{base_name}[currency]")
      |> assign(:amount_id, "#{base_id}_amount")
      |> assign(:currency_id, "#{base_id}_currency")
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
      |> assign_new(:symbol_class, fn -> nil end)
    end

    defp assign_money_locale_data(assigns) do
      locale = assigns[:locale] || Localize.get_locale()

      {:ok, locale_data} =
        Currency.currency_for_locale(locale,
          currency: assigns.effective_currency,
          symbol_kind: assigns.symbol_kind
        )

      assigns
      |> assign(:locale, locale)
      |> assign(:locale_data, locale_data)
    end

    defp assign_symbol_position(assigns) do
      position =
        case assigns.symbol_position do
          :auto -> assigns.locale_data.symbol_position || :prefix
          explicit -> explicit
        end

      assign(assigns, :symbol_position, position)
    end

    defp assign_picker(assigns) do
      allowed = assigns.allowed || curated_currencies()
      preferred = assigns.preferred || []
      locale_id = locale_id(assigns.locale)

      {:ok, locale_data} = Currency.currency_for_locale(locale_id)

      preferred_rows =
        preferred
        |> Enum.map(&currency_row(&1, locale_id))
        |> Enum.reject(&is_nil/1)

      all_rows =
        allowed
        |> Enum.reject(&(&1 in preferred))
        |> Enum.map(&currency_row(&1, locale_id))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.name)

      sections = [
        {"Preferred", preferred_rows},
        {"All currencies", all_rows}
      ]

      id = assigns[:id] || "currency-picker-#{System.unique_integer([:positive])}"

      # The hidden value input is named via three priority levels:
      # 1) an explicit `name=` attr (used when embedded in money_input
      #    to inject a nested name like `price[currency]`),
      # 2) a form+field pair (standalone use),
      # 3) nothing — the picker is purely client-side state.
      {hidden_name, hidden_id} =
        case {assigns[:name], assigns[:form], assigns[:field]} do
          {explicit, _, _} when is_binary(explicit) ->
            {explicit, assigns[:input_id] || "#{id}-value"}

          {_, form, field} when not is_nil(form) and not is_nil(field) ->
            {Phoenix.HTML.Form.input_name(form, field), "#{id}-value"}

          _ ->
            {nil, nil}
        end

      assigns
      |> assign(:sections, sections)
      |> assign(:locale_id, locale_data.locale)
      |> assign(:id, id)
      |> assign(:hidden_name, hidden_name)
      |> assign(:hidden_id, hidden_id)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:button_class, fn -> nil end)
      |> assign_new(:overlay_class, fn -> nil end)
      |> assign_new(:row_class, fn -> nil end)
    end

    defp currency_row(code, locale_id) do
      case Money.Currency.currency_for_code(code) do
        {:ok, currency} ->
          %{
            code: to_string(code),
            name: localized_currency_name(code, currency, locale_id),
            country: Flags.country_for(code) || "",
            symbol: currency.symbol,
            flag: flag_for(code),
            iso_digits: currency.iso_digits
          }

        _ ->
          nil
      end
    end

    # CLDR display names for currencies vary by locale (e.g. "Euro"
    # in en, "Euro" in de, "ユーロ" in ja, "يورو" in ar). Fall
    # back to the struct's English `:name` if the locale lookup
    # doesn't carry this currency.
    defp localized_currency_name(code, fallback, locale_id) do
      case Localize.Currency.display_name(code, locale: locale_id) do
        {:ok, name} -> name
        {:error, _} -> to_string(fallback.name)
      end
    end

    defp curated_currencies do
      ~w(USD EUR GBP JPY CHF CAD AUD NZD CNY HKD SGD KRW INR BRL MXN ZAR
         SEK NOK DKK PLN CZK HUF RON TRY RUB ILS AED SAR EGP THB IDR PHP
         MYR VND TWD UAH ARS COP PEN CLP PKR BDT NGN KES KZT MAD CHF BHD KWD)a
      |> Enum.uniq()
    end

    defp locale_id(nil), do: Localize.get_locale()
    defp locale_id(locale), do: locale

    defp value_attr(nil), do: nil
    defp value_attr(value), do: to_string(value)

    defp text_align_class(:left), do: "text-left"
    defp text_align_class(:center), do: "text-center"
    defp text_align_class(:right), do: "text-right"

    # Used by the input's sr-only currency-name span. Prefers the
    # CLDR display name for the active locale; falls back to the
    # struct's English `:name` field if the CLDR lookup misses.
    defp currency_name(nil, _locale), do: ""

    defp currency_name(%{code: code, name: fallback}, locale) when not is_nil(code) do
      localized_currency_name(code, %{name: fallback}, locale)
    end

    defp currency_name(%{name: name}, _locale) when is_binary(name), do: name
    defp currency_name(_, _), do: ""

    defp flag_for(code) when is_atom(code), do: Flags.flag_for(code)
    defp flag_for(_), do: "🏳"
  end
end
