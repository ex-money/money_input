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
      "<!doctype html><html lang=\"en\">",
      "<head>",
      "<meta charset=\"utf-8\">",
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
      "<title>",
      escape(title),
      " — Money.Input.Visualizer</title>",
      # Load the component CSS first, then the visualizer's own
      # stylesheet. Both use `--mi-*` CSS variables; loading
      # order matters because the visualizer's vars and explicit
      # class overrides (e.g. `.money-input-wrapper { background:
      # var(--mi-surface-2); }`) need to win the cascade so the
      # embedded components inherit the light/dark theme.
      "<link rel=\"stylesheet\" href=\"",
      escape(base),
      "/assets/money_input.css\">",
      "<link rel=\"stylesheet\" href=\"",
      escape(base),
      "/assets/style.css\">",
      "<link rel=\"icon\" type=\"image/png\" href=\"",
      escape(base),
      "/assets/logo.png\">",
      # Apply the saved theme synchronously before paint to avoid
      # a flash of the wrong palette. The script reads from
      # localStorage (set by the toggle below) and sets a
      # `data-theme` attribute on `<html>`. When no preference is
      # stored, the CSS falls back to prefers-color-scheme.
      theme_init_script(),
      "</head><body>",
      header(active, base),
      "<main class=\"mi-main\">",
      error_block(error),
      body,
      footer(),
      "</main>",
      theme_toggle_script(),
      "</body></html>"
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
      "<div class=\"mi-header-top\">",
      "<a class=\"mi-brand\" href=\"",
      escape(base),
      "/\">",
      "<img class=\"mi-logo\" src=\"",
      escape(base),
      "/assets/logo.png\" alt=\"\" width=\"40\" height=\"40\">",
      "<div class=\"mi-brand-text\">",
      "<h1>Money.Input.Visualizer</h1>",
      "<p>locale-aware number &amp; money input — try how it behaves across locales and currencies</p>",
      "</div>",
      "</a>",
      theme_toggle(),
      "</div>",
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

  # 3-way segmented control: system / light / dark. JS in
  # `theme_toggle_script/0` wires the click handling and keeps
  # `data-active` on the wrapper in sync with the saved choice.
  # System uses an inline desktop icon, light a sun, dark a moon.
  defp theme_toggle do
    """
    <div class="mi-theme-toggle" data-mi-theme-toggle data-active="system" role="group" aria-label="Theme">
      <button type="button" data-theme-choice="system" aria-pressed="true" aria-label="Use system theme" title="System">
        <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg>
      </button>
      <button type="button" data-theme-choice="light" aria-pressed="false" aria-label="Use light theme" title="Light">
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
      </button>
      <button type="button" data-theme-choice="dark" aria-pressed="false" aria-label="Use dark theme" title="Dark">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>
      <span class="mi-theme-toggle-thumb" aria-hidden="true"></span>
    </div>
    """
  end

  defp theme_init_script do
    """
    <script>
      (function () {
        try {
          var saved = localStorage.getItem('money_input:theme');
          if (saved === 'light' || saved === 'dark') {
            document.documentElement.setAttribute('data-theme', saved);
          }
        } catch (_) { /* private mode, ignore */ }
      })();
    </script>
    """
  end

  defp theme_toggle_script do
    """
    <script>
      (function () {
        var STORAGE_KEY = 'money_input:theme';
        var toggle = document.querySelector('[data-mi-theme-toggle]');
        if (!toggle) return;

        function active() {
          try {
            var saved = localStorage.getItem(STORAGE_KEY);
            return (saved === 'light' || saved === 'dark') ? saved : 'system';
          } catch (_) {
            return 'system';
          }
        }

        function apply(choice) {
          try {
            if (choice === 'system') {
              localStorage.removeItem(STORAGE_KEY);
              document.documentElement.removeAttribute('data-theme');
            } else {
              localStorage.setItem(STORAGE_KEY, choice);
              document.documentElement.setAttribute('data-theme', choice);
            }
          } catch (_) {
            // Fall back to attribute-only when storage is blocked.
            if (choice === 'system') {
              document.documentElement.removeAttribute('data-theme');
            } else {
              document.documentElement.setAttribute('data-theme', choice);
            }
          }
          toggle.setAttribute('data-active', choice);
          toggle.querySelectorAll('button').forEach(function (btn) {
            btn.setAttribute('aria-pressed', btn.getAttribute('data-theme-choice') === choice ? 'true' : 'false');
          });
        }

        apply(active());

        toggle.addEventListener('click', function (e) {
          var btn = e.target.closest('button[data-theme-choice]');
          if (!btn) return;
          apply(btn.getAttribute('data-theme-choice'));
        });
      })();
    </script>
    """
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
    reactive = if Keyword.get(options, :reactive, false), do: " data-mi-reactive", else: ""

    # Always include the currently-selected locale and any extras
    # the caller requested (typically the deployment's default
    # locale, so it stays accessible after the user picks
    # something else).
    extras = [selected | Keyword.get(options, :always_include, [])]
    locales = ensure_all_in_list(locale_options(), extras)

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

  # Prepend any locale that isn't already in the curated list.
  # Two cases this handles:
  #
  #   1. The currently-selected locale — without this, picking
  #      `en-AU` (not in the curated set) would render with no
  #      `<option selected>`, so the browser would show the
  #      first option as the apparent selection.
  #
  #   2. The deployment's default locale — passed in via
  #      `always_include`. Without it, the dropdown would *show*
  #      the default at first render (case 1 above), but the
  #      user picking another locale would remove it from the
  #      list permanently with no way to get back.
  #
  # Entries are de-duplicated, blanks filtered, label text comes
  # from CLDR's locale-display data.
  defp ensure_all_in_list(locales, extras) do
    extras
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.reverse()
    |> Enum.reduce(locales, &prepend_if_missing/2)
  end

  defp prepend_if_missing(locale_id, locales) do
    if Enum.any?(locales, fn {value, _} -> to_string(value) == locale_id end) do
      locales
    else
      [{locale_id, locale_label_for(locale_id)} | locales]
    end
  end

  defp locale_label_for(locale_id) do
    case locale_display_name(locale_id) do
      {:ok, name} -> name
      _ -> locale_id
    end
  end

  defp locale_display_name(locale_id) do
    Localize.Locale.LocaleDisplay.display_name(locale_id)
  rescue
    _ -> :error
  catch
    _, _ -> :error
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
