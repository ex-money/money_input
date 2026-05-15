defmodule Money.Input.Visualizer.ParseView do
  @moduledoc false

  # Cross-locale parse table. Take one input string and show what
  # Money.Input.Parser returns under every demo locale, with the
  # currency fixed. Useful for seeing how 1.234,56 means different
  # things to en vs. de.

  alias Money.Input.Parser
  alias Money.Input.Visualizer.Render

  def render(params, base) do
    input = params.input
    currency = params.currency
    mode = params.mode

    rows =
      for {locale, label} <- Render.locale_options() do
        result =
          case mode do
            :number -> Parser.parse_number(input, locale: locale)
            :money -> Parser.parse_money(input, locale: locale, currency: currency)
          end

        {locale, label, result}
      end

    body = [
      "<section class=\"mi-card\">",
      "<h2>Cross-locale parsing</h2>",
      "<p class=\"mi-desc\">Same input, every locale. Demonstrates how ",
      "<code>Money.Input.Parser</code> interprets the decimal and ",
      "grouping separators per locale — and why a US user pasting ",
      "<code>1,234.56</code> while their app is on <code>de</code> ",
      "needs tolerant handling.</p>",
      "<form method=\"get\" action=\"",
      Render.escape(base),
      "/parse\" class=\"mi-form\">",
      "<div class=\"mi-field mi-field-wide\">",
      "<label><span>Input</span>",
      "<input type=\"text\" name=\"input\" value=\"",
      Render.escape(input),
      "\" autocomplete=\"off\"></label>",
      "</div>",
      Render.field("Mode", mode_select(mode)),
      Render.field("Currency (money mode)", Render.currency_select("currency", currency)),
      "<div class=\"mi-actions\">",
      "<button class=\"mi-btn\" type=\"submit\">Parse across locales</button>",
      "<span class=\"mi-hint\">Try <code>1,234.56</code>, <code>1.234,56</code>, ",
      "<code>1 234,56</code>, <code>(1234.56)</code>, <code>$1,234.56</code></span>",
      "</div>",
      "</form>",
      result_table(rows, mode),
      "</section>"
    ]

    Render.page(
      title: "Parse",
      active: "parse",
      base: base,
      body: body
    )
  end

  defp mode_select(selected) do
    options = [{"number", "Plain number"}, {"money", "Money"}]

    [
      "<select name=\"mode\">",
      Enum.map(options, fn {value, label} ->
        sel = if value == to_string(selected), do: " selected", else: ""

        [
          "<option value=\"",
          Render.escape(value),
          "\"",
          sel,
          ">",
          Render.escape(label),
          "</option>"
        ]
      end),
      "</select>"
    ]
  end

  defp result_table(rows, mode) do
    [
      "<table class=\"mi-table\">",
      "<thead><tr>",
      "<th>Locale</th><th>Result</th><th>Canonical</th><th>Round-trip</th>",
      "</tr></thead>",
      "<tbody>",
      Enum.map(rows, &result_row(&1, mode)),
      "</tbody>",
      "</table>"
    ]
  end

  defp result_row({locale, label, {:ok, nil}}, _mode) do
    [
      "<tr>",
      "<td>",
      Render.escape(locale),
      " <small>(",
      Render.escape(label),
      ")</small></td>",
      "<td colspan=\"3\"><em>(empty)</em></td>",
      "</tr>"
    ]
  end

  defp result_row({locale, label, {:ok, value}}, mode) do
    canonical = Money.Input.Parser.to_canonical(value)

    round_trip =
      case mode do
        :number -> Money.Input.Formatter.format_number(value, locale: locale)
        :money -> Money.Input.Formatter.format_money(value, locale: locale)
      end

    [
      "<tr>",
      "<td>",
      Render.escape(locale),
      " <small>(",
      Render.escape(label),
      ")</small></td>",
      "<td class=\"mi-mono\">",
      Render.escape(describe_value(value)),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(canonical),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(round_trip),
      "</td>",
      "</tr>"
    ]
  end

  defp result_row({locale, label, {:error, reason}}, _mode) do
    [
      "<tr>",
      "<td>",
      Render.escape(locale),
      " <small>(",
      Render.escape(label),
      ")</small></td>",
      "<td colspan=\"3\" class=\"mi-bad mi-mono\">",
      Render.escape(inspect(reason)),
      "</td>",
      "</tr>"
    ]
  end

  defp describe_value(%Money{} = money) do
    "#{money.currency} #{Decimal.to_string(money.amount, :normal)}"
  end

  defp describe_value(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
  defp describe_value(value), do: inspect(value)
end
