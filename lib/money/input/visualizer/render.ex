defmodule Money.Input.Visualizer.Render do
  @moduledoc false

  # Shared HTML helpers for the visualizer. Pure functions,
  # iodata in / iodata out. No templates.

  @doc "HTML-escapes a binary or iodata."
  @spec escape(iodata() | term()) :: iodata()
  def escape(iodata) when is_list(iodata), do: Enum.map(iodata, &escape/1)

  def escape(binary) when is_binary(binary) do
    binary
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def escape(other), do: escape(to_string(other))

  @doc "Wraps body iodata in the full HTML page chrome."
  def page(assigns) do
    title = Keyword.fetch!(assigns, :title)
    active = Keyword.fetch!(assigns, :active)
    body = Keyword.fetch!(assigns, :body)
    base = Keyword.fetch!(assigns, :base)
    error = Keyword.get(assigns, :error)

    [
      "<!doctype html><html lang=\"en\"><head>",
      "<meta charset=\"utf-8\">",
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
      "<title>",
      escape(title),
      " — Money.Input.Visualizer</title>",
      "<link rel=\"stylesheet\" href=\"",
      escape(base),
      "/assets/style.css\">",
      "</head><body>",
      header(active, base),
      "<main class=\"mi-main\">",
      error_block(error),
      body,
      footer(),
      "</main></body></html>"
    ]
  end

  defp header(active, base) do
    tabs = [
      {"input", "Input"},
      {"parse", "Parse"},
      {"format", "Format"},
      {"locale", "Locale"}
    ]

    [
      "<header class=\"mi-header\">",
      "<a class=\"mi-brand\" href=\"",
      escape(base),
      "/\"><h1>Money.Input.Visualizer</h1>",
      "<p>locale-aware number &amp; money input — try how it behaves across locales and currencies</p>",
      "</a>",
      "<nav class=\"mi-tabs\">",
      Enum.map(tabs, fn {path, label} ->
        cls = if path == active, do: "active", else: ""

        [
          "<a href=\"",
          escape(base),
          "/",
          path,
          "\" class=\"",
          cls,
          "\">",
          label,
          "</a>"
        ]
      end),
      "</nav>",
      "</header>"
    ]
  end

  defp error_block(nil), do: ""

  defp error_block(message) do
    ["<div class=\"mi-error\">", escape(to_string(message)), "</div>"]
  end

  defp footer do
    [
      "<footer class=\"mi-footer\">",
      "<p>Headless API: <code>Money.Input.Parser</code>, ",
      "<code>Money.Input.Formatter</code>, ",
      "<code>Money.Input.Validator</code>, ",
      "<code>Money.Input.Locale</code>.</p>",
      "</footer>"
    ]
  end

  @doc """
  Renders a `<select>` for a locale chooser.

  Accepts an options keyword list: `:reactive` (boolean) adds a
  `data-mi-reactive` attribute that the bootstrap JS listens to,
  so changing the value re-submits the form immediately.
  """
  def locale_select(name, selected, options \\ []) do
    locales = locale_options()
    reactive = if Keyword.get(options, :reactive, false), do: " data-mi-reactive", else: ""

    [
      "<select name=\"",
      escape(name),
      "\"",
      reactive,
      ">",
      Enum.map(locales, fn {value, label} ->
        sel = if to_string(value) == to_string(selected), do: " selected", else: ""

        [
          "<option value=\"",
          escape(value),
          "\"",
          sel,
          ">",
          escape(label),
          "</option>"
        ]
      end),
      "</select>"
    ]
  end

  @doc """
  Renders a `<select>` for a currency chooser.

  Accepts an options keyword list: `:allow_blank` adds a "— none —"
  option at the top; `:reactive` makes the select submit the form
  immediately on change.
  """
  def currency_select(name, selected, options \\ []) do
    allow_blank = Keyword.get(options, :allow_blank, false)
    reactive = if Keyword.get(options, :reactive, false), do: " data-mi-reactive", else: ""
    currencies = currency_options()

    blank =
      if allow_blank do
        sel = if selected in [nil, ""], do: " selected", else: ""
        ["<option value=\"\"", sel, ">— none —</option>"]
      else
        ""
      end

    [
      "<select name=\"",
      escape(name),
      "\"",
      reactive,
      ">",
      blank,
      Enum.map(currencies, fn {code, name} ->
        sel = if to_string(code) == to_string(selected), do: " selected", else: ""

        [
          "<option value=\"",
          escape(code),
          "\"",
          sel,
          ">",
          escape(code),
          " — ",
          escape(name),
          "</option>"
        ]
      end),
      "</select>"
    ]
  end

  @doc """
  Returns the list of demo locales the visualizer offers.
  """
  def locale_options do
    [
      {"en", "English (US)"},
      {"en-GB", "English (UK)"},
      {"en-IN", "English (India)"},
      {"de", "German (Germany)"},
      {"de-CH", "German (Switzerland)"},
      {"fr", "French (France)"},
      {"fr-CH", "French (Switzerland)"},
      {"es", "Spanish (Spain)"},
      {"pt-BR", "Portuguese (Brazil)"},
      {"it", "Italian"},
      {"ja", "Japanese"},
      {"zh-Hans", "Chinese (Simplified)"},
      {"ar", "Arabic"},
      {"fa", "Persian"},
      {"he", "Hebrew"},
      {"ru", "Russian"},
      {"sv", "Swedish"},
      {"pl", "Polish"}
    ]
  end

  @doc """
  Returns the curated list of demo currencies.
  """
  def currency_options do
    [
      {"USD", "US Dollar"},
      {"EUR", "Euro"},
      {"GBP", "Pound Sterling"},
      {"JPY", "Japanese Yen"},
      {"CHF", "Swiss Franc"},
      {"CAD", "Canadian Dollar"},
      {"AUD", "Australian Dollar"},
      {"BRL", "Brazilian Real"},
      {"INR", "Indian Rupee"},
      {"CNY", "Chinese Yuan"},
      {"SAR", "Saudi Riyal"},
      {"BHD", "Bahraini Dinar"},
      {"KWD", "Kuwaiti Dinar"},
      {"SEK", "Swedish Krona"},
      {"NOK", "Norwegian Krone"},
      {"ZAR", "South African Rand"}
    ]
  end

  @doc """
  Renders a labelled form row.
  """
  def field(label, control, opts \\ []) do
    hint = Keyword.get(opts, :hint)

    [
      "<div class=\"mi-field\">",
      "<label>",
      escape(label),
      control,
      "</label>",
      if(hint, do: ["<small class=\"mi-hint\">", escape(hint), "</small>"], else: ""),
      "</div>"
    ]
  end

  @doc """
  Pretty-prints an arbitrary Elixir term.
  """
  def code(term) do
    ["<pre class=\"mi-code\">", escape(inspect(term, pretty: true, width: 60)), "</pre>"]
  end
end
