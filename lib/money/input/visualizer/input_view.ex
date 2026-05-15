defmodule Money.Input.Visualizer.InputView do
  @moduledoc false

  # Live demo of the actual Money.Input.Components. Renders the
  # number_input, money_input, and currency_picker components
  # server-side, then bootstraps AutoNumeric and our picker JS
  # on the rendered DOM so they behave live in the browser.

  alias Money.Input.{Cast, Formatter, Locale, Parser, Validator}
  alias Money.Input.Components
  alias Money.Input.Visualizer.Render

  def render(params, base) do
    locale = params.locale
    default_currency = params.default_currency
    number_input = params.number_input
    money_input = params.money_input
    picker = params.picker
    preferred = params.preferred_currencies

    number_result = parse_number_result(number_input, locale)
    money_result = parse_money_result(money_input, locale, default_currency)
    {:ok, locale_data} = Locale.resolve(locale, currency: default_currency)

    body = [
      "<section class=\"mi-card\">",
      "<h2>The components</h2>",
      "<p class=\"mi-desc\">Live HEEx renders of ",
      "<code>Money.Input.Components.number_input/1</code>, ",
      "<code>Money.Input.Components.money_input/1</code>, and ",
      "<code>Money.Input.Components.currency_picker/1</code>. With ",
      "AutoNumeric loaded the inputs format as you type and ",
      "preserve cursor position; the picker is fully interactive ",
      "(search, recents in <code>localStorage</code>, keyboard ",
      "nav). The visualizer mounts the same hooks the components ",
      "expose to LiveView consumers.</p>",
      "<form method=\"get\" action=\"",
      Render.escape(base),
      "/input\" class=\"mi-form\">",
      ~s(<input type="hidden" name="submitted" value="1">),
      Render.field(
        "Locale",
        Render.locale_select("locale", locale, reactive: true)
      ),
      Render.field(
        "Default currency",
        Render.currency_select("default_currency", default_currency, reactive: true),
        hint:
          "Used when the form value doesn't carry a currency. Maps to the component's `:default_currency` attr."
      ),
      picker_toggle(picker),
      preferred_currencies_field(preferred),
      live_number_input_field(locale, locale_data, number_input),
      live_money_input_field(
        locale,
        default_currency,
        locale_data,
        money_input,
        picker,
        preferred
      ),
      "<div class=\"mi-actions\">",
      "<button class=\"mi-btn\" type=\"submit\">Parse &amp; format</button>",
      "<span class=\"mi-hint\">Try ",
      sample_hint(locale_data),
      "</span>",
      "</div>",
      "</form>",
      "</section>",
      result_card("number_input result", number_result),
      result_card("money_input result", money_result),
      code_card(locale, default_currency, picker, preferred),
      locale_card(locale_data),
      bootstrap_script(base)
    ]

    Render.page(
      title: "Input",
      active: "input",
      base: base,
      body: body
    )
  end

  defp live_number_input_field(locale, _locale_data, value) do
    form = make_form("number_input", value)

    assigns = %{
      form: form,
      field: :number_input,
      locale: locale,
      __changed__: nil,
      class: nil,
      input_class: nil,
      align: :left,
      integer: false,
      min: nil,
      max: nil,
      decimals: nil,
      placeholder: nil,
      js: true,
      value: nil,
      rest: %{}
    }

    rendered = Components.number_input(assigns)

    [
      "<div class=\"mi-field mi-field-wide\">",
      "<label>",
      "<span>Number input</span>",
      Phoenix.HTML.Safe.to_iodata(rendered),
      "</label>",
      "<small class=\"mi-hint\">phx-hook=\"NumberInput\" — wraps AutoNumeric when present</small>",
      "</div>"
    ]
  end

  defp live_money_input_field(locale, default_currency, _locale_data, value, picker, preferred) do
    form =
      make_form("money_input", value, %{
        "currency" => default_currency && to_string(default_currency)
      })

    assigns = %{
      form: form,
      field: :money_input,
      currency_field: :currency,
      locale: locale,
      default_currency: default_currency,
      __changed__: nil,
      class: nil,
      input_class: nil,
      symbol_class: nil,
      align: :right,
      min: nil,
      max: nil,
      placeholder: nil,
      js: true,
      value: nil,
      symbol_position: :auto,
      symbol_kind: :symbol,
      currency_picker: picker,
      allowed_currencies: nil,
      preferred_currencies: preferred,
      rest: %{}
    }

    rendered = Components.money_input(assigns)

    [
      "<div class=\"mi-field mi-field-wide\">",
      "<label>",
      "<span>Money input <span class=\"mi-pill\">",
      Render.escape(picker_pill(picker, default_currency)),
      "</span></span>",
      Phoenix.HTML.Safe.to_iodata(rendered),
      "</label>",
      "<small class=\"mi-hint\">",
      picker_hint(picker),
      "</small>",
      "</div>"
    ]
  end

  defp picker_pill(true, _currency), do: "with picker"
  defp picker_pill(_, currency), do: to_string(currency)

  defp picker_hint(true),
    do: "phx-hook=\"MoneyInput\" + embedded <code>&lt;.currency_picker&gt;</code>"

  defp picker_hint(_), do: "phx-hook=\"MoneyInput\" — fixed currency via attr"

  defp picker_toggle(picker_on) do
    checked = if picker_on, do: " checked", else: ""

    [
      "<div class=\"mi-field\">",
      "<label>",
      "<span>Currency picker</span>",
      "<span class=\"mi-checkbox\">",
      ~s(<input type="checkbox" name="picker" value="1" data-mi-reactive),
      checked,
      ~s(> Embed <code>&lt;.currency_picker&gt;</code> in <code>money_input</code>),
      "</span>",
      "</label>",
      "</div>"
    ]
  end

  defp preferred_currencies_field(preferred) do
    value = preferred |> Enum.map_join(", ", &to_string/1)

    [
      "<div class=\"mi-field\">",
      "<label>",
      "<span>Preferred currencies</span>",
      ~s(<input type="text" name="preferred" data-mi-reactive value="),
      Render.escape(value),
      ~s(" placeholder="USD, EUR, GBP, JPY">),
      "</label>",
      ~s(<small class="mi-hint">Comma-separated ISO codes — pinned to the top of the picker. Tab out or press Enter to apply.</small>),
      "</div>"
    ]
  end

  defp make_form(field, value, extra \\ %{}) do
    # `as: nil` keeps field names flat (e.g. `currency` rather
    # than `demo[currency]`), so the picker's hidden input round-
    # trips through the visualizer's URL params (which are also
    # flat) when the form is submitted.
    params = Map.merge(extra, %{Atom.to_string(field |> ensure_atom()) => value || ""})
    Phoenix.HTML.FormData.to_form(params, as: nil)
  end

  defp ensure_atom(atom) when is_atom(atom), do: atom
  defp ensure_atom(string) when is_binary(string), do: String.to_atom(string)

  defp result_card(_title, nil), do: ""

  defp result_card(title, rows) when is_list(rows) do
    rendered =
      Enum.map(rows, fn {label, value, css_class} ->
        [
          "<dt>",
          Render.escape(label),
          "</dt>",
          "<dd class=\"",
          Render.escape(css_class || ""),
          "\">",
          Render.escape(value),
          "</dd>"
        ]
      end)

    [
      "<section class=\"mi-card\">",
      "<h2>",
      Render.escape(title),
      "</h2>",
      "<dl class=\"mi-result\">",
      rendered,
      "</dl>",
      "</section>"
    ]
  end

  defp code_card(locale, default_currency, picker, preferred) do
    number_code = build_number_call(locale)
    money_code = build_money_call(locale, default_currency, picker, preferred)

    [
      "<section class=\"mi-card\">",
      "<h2>Component code</h2>",
      "<p class=\"mi-desc\">The HEEx call sites that render the inputs above. ",
      "Tweak the form controls and the code refreshes — copy straight into a ",
      "LiveView template.</p>",
      "<pre class=\"mi-code\">",
      Render.escape(number_code),
      "\n\n",
      Render.escape(money_code),
      "</pre>",
      "</section>"
    ]
  end

  defp build_number_call(locale) do
    """
    <.number_input
      form={@form}
      field={:quantity}
      locale=#{format_locale_attr(locale)}
    />\
    """
  end

  defp build_money_call(locale, default_currency, picker, preferred) do
    attrs =
      [
        ~s(  form={@form}),
        ~s(  field={:price}),
        format_attr("locale", format_locale_attr(locale)),
        default_currency && format_attr("default_currency", ":#{default_currency}", curly: true),
        picker && format_attr("currency_picker", "true", curly: true),
        picker && preferred != [] &&
          format_attr("preferred_currencies", format_atom_list(preferred), curly: true)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == false))

    "<.money_input\n" <> Enum.join(attrs, "\n") <> "\n/>"
  end

  defp format_attr(name, value, options \\ []) do
    if Keyword.get(options, :curly, false) do
      "  #{name}={#{value}}"
    else
      "  #{name}=#{value}"
    end
  end

  defp format_locale_attr(locale) when is_binary(locale), do: ~s("#{locale}")
  defp format_locale_attr(locale) when is_atom(locale), do: ~s(:#{locale})

  defp format_atom_list(list) do
    inner = list |> Enum.map_join(", ", fn atom -> ":#{atom}" end)
    "[" <> inner <> "]"
  end

  defp locale_card(locale_data) do
    [
      "<section class=\"mi-card\">",
      "<h2>Resolved locale data</h2>",
      "<p class=\"mi-desc\">What <code>Money.Input.Locale.resolve/2</code> ",
      "returns for the current locale + currency combination — the ",
      "data the JS hook reads from <code>data-</code> attributes.</p>",
      Render.code(locale_data)
    ]
  end

  defp parse_number_result(nil, _locale), do: nil
  defp parse_number_result("", _locale), do: nil

  defp parse_number_result(value, locale) do
    case Parser.parse_number(value, locale: locale) do
      {:ok, nil} ->
        nil

      {:ok, parsed} ->
        canonical = Parser.to_canonical(parsed)
        formatted = Formatter.format_number(parsed, locale: locale)
        validation = Validator.validate_number(parsed)

        [
          {"Input", value, nil},
          {"Parsed (Decimal)", inspect(parsed), nil},
          {"Canonical wire value", canonical, nil},
          {"Blur format (#{locale})", formatted, nil},
          {"Validation", inspect(validation), validation_css(validation)}
        ]

      {:error, reason} ->
        [
          {"Input", value, nil},
          {"Error", inspect(reason), "mi-bad"}
        ]
    end
  end

  defp parse_money_result(nil, _locale, _currency), do: nil
  defp parse_money_result("", _locale, _currency), do: nil
  defp parse_money_result(%{"amount" => "", "currency" => _}, _locale, _currency), do: nil

  # The form submits the money field as a nested map
  # `%{"amount" => "...", "currency" => "..."}`. We cast it
  # with `Money.Input.Cast.cast/2` — the same code path
  # `Money.Ecto.Composite.Type.cast/1` and
  # `Money.Input.Changeset.cast_money/3` use. (Note: parsing is
  # for *strings* and lives in `Money.Input.Parser`. Casting is
  # for structured form submissions — different operation.)
  defp parse_money_result(value, locale, currency) do
    case Cast.cast(value, locale: locale, currency: currency) do
      {:ok, nil} ->
        nil

      {:ok, %Money{} = money} ->
        canonical = Parser.to_canonical(money)
        formatted = Formatter.format_money(money, locale: locale)
        symbol_off = Formatter.format_money(money, locale: locale, no_symbol: true)
        validation = Validator.validate_money(money)

        [
          {"Submitted params", describe_money_submission(value), nil},
          {"Cast to Money", Money.to_string!(money) <> "  (" <> inspect(money) <> ")", nil},
          {"Canonical wire value", canonical, nil},
          {"Blur format (#{locale})", formatted, nil},
          {"Number portion only", symbol_off, nil},
          {"Validation", inspect(validation), validation_css(validation)}
        ]

      {:error, reason} ->
        [
          {"Submitted params", describe_money_submission(value), nil},
          {"Error", inspect(reason), "mi-bad"}
        ]
    end
  end

  defp describe_money_submission(%{} = map) do
    amount = Map.get(map, "amount") || Map.get(map, :amount) || ""
    currency = Map.get(map, "currency") || Map.get(map, :currency) || ""
    ~s(%{"amount" => "#{amount}", "currency" => "#{currency}"})
  end

  defp describe_money_submission(value), do: inspect(value)

  defp validation_css(:ok), do: nil
  defp validation_css(_), do: "mi-bad"

  defp sample_hint(%{decimal: dec, group: grp}) do
    "1#{grp}234#{dec}56"
  end

  # The visualizer is not a LiveView, so it bootstraps the hooks
  # by hand: pluck each [phx-hook="..."] element, call the hook's
  # `mounted/0` with `this.el` shimmed in. This is just enough to
  # demonstrate the components in a non-Phoenix dev page.
  defp bootstrap_script(base) do
    [
      "<link rel=\"stylesheet\" href=\"",
      Render.escape(base),
      "/assets/money_input.css\">",
      "<script src=\"https://cdn.jsdelivr.net/npm/autonumeric@4.10.0/dist/autoNumeric.min.js\"></script>",
      "<script type=\"module\">",
      "import Hooks from \"",
      Render.escape(base),
      "/assets/money_input.js\";\n",
      "Hooks.configure({ AutoNumeric: window.AutoNumeric });\n",
      "function mount(selector, hook) {\n",
      "  document.querySelectorAll(selector).forEach(el => {\n",
      "    const instance = Object.assign(Object.create(hook), { el });\n",
      "    instance.mounted();\n",
      "  });\n",
      "}\n",
      "mount('[phx-hook=\"NumberInput\"]', Hooks.NumberInput);\n",
      "mount('[phx-hook=\"MoneyInput\"]', Hooks.MoneyInput);\n",
      "mount('[phx-hook=\"CurrencyPicker\"]', Hooks.CurrencyPicker);\n",
      # Reactive form: changing locale, default currency, picker
      # checkbox, or preferred currencies submits the form right
      # away so the page re-renders with the new state. Each
      # control opts in by carrying `data-mi-reactive`.
      "document.querySelectorAll('[data-mi-reactive]').forEach(el => {\n",
      "  el.addEventListener('change', () => {\n",
      "    const form = el.closest('form');\n",
      "    if (form) form.submit();\n",
      "  });\n",
      "});\n",
      # Enter inside the preferred-currencies text input would
      # normally fire native form submission, which is what we
      # want — but blur also fires `change`, so users tabbing out
      # see the update without an explicit submit too.
      "</script>"
    ]
  end
end
