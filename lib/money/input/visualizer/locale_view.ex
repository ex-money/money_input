defmodule Money.Input.Visualizer.LocaleView do
  @moduledoc false

  # A side-by-side card of Money.Input.Currency.currency_for_locale/2
  # output for every demo locale + the chosen currency. This is
  # the data a JS hook (e.g. AutoNumeric) would read from data-
  # attributes to render an input correctly.

  alias Money.Input.Currency
  alias Money.Input.Visualizer.Render

  def render(params, base) do
    currency = params.currency

    locale_rows =
      for {locale, label} <- Render.locale_options() do
        {locale, label, Currency.currency_for_locale(locale, currency: currency)}
      end

    body = [
      "<section class=\"mi-card\">",
      "<h2>Locale display data</h2>",
      "<p class=\"mi-desc\">For every demo locale, the snapshot that ",
      "<code>Money.Input.Currency.currency_for_locale/2</code> returns. ",
      "This is what the server-side render writes into ",
      "<code>data-</code> attributes for the JS hook to read.</p>",
      "<form method=\"get\" action=\"",
      Render.escape(base),
      "/locale\" class=\"mi-form\">",
      Render.field(
        "Currency",
        Render.currency_select("currency", currency, allow_blank: true)
      ),
      "<div class=\"mi-actions\">",
      "<button class=\"mi-btn\" type=\"submit\">Inspect locales</button>",
      "</div>",
      "</form>",
      table(locale_rows),
      "</section>"
    ]

    Render.page(
      title: "Locale",
      active: "locale",
      base: base,
      body: body
    )
  end

  defp table(rows) do
    [
      "<table class=\"mi-table\">",
      "<thead><tr>",
      "<th>Locale</th>",
      "<th>Decimal</th>",
      "<th>Group</th>",
      "<th>Minus</th>",
      "<th>Digits</th>",
      "<th>Currency</th>",
      "<th>Symbol</th>",
      "<th>Position</th>",
      "<th>ISO digits</th>",
      "</tr></thead>",
      "<tbody>",
      Enum.map(rows, &row/1),
      "</tbody></table>"
    ]
  end

  defp row({locale, label, {:ok, data}}) do
    [
      "<tr>",
      "<td>",
      Render.escape(locale),
      " <small>(",
      Render.escape(label),
      ")</small></td>",
      "<td class=\"mi-mono\">",
      Render.escape(data.decimal),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(data.group),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(data.minus_sign),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(to_string(data.number_system)),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(currency_label(data.currency)),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape(data.symbol || "—"),
      "</td>",
      "<td>",
      Render.escape(to_string(data.symbol_position || "—")),
      "</td>",
      "<td class=\"mi-mono\">",
      Render.escape((data.iso_digits && to_string(data.iso_digits)) || "—"),
      "</td>",
      "</tr>"
    ]
  end

  defp row({locale, label, {:error, reason}}) do
    [
      "<tr><td>",
      Render.escape(locale),
      " <small>(",
      Render.escape(label),
      ")</small></td>",
      "<td colspan=\"8\" class=\"mi-bad mi-mono\">",
      Render.escape(inspect(reason)),
      "</td></tr>"
    ]
  end

  defp currency_label(nil), do: "—"
  defp currency_label(%{code: code}), do: to_string(code)
end
