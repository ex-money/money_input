defmodule Money.Input.Visualizer.Assets do
  @moduledoc false

  # Static assets for the visualizer. Inline CSS keeps the
  # visualizer dependency-free at the asset layer.
  #
  # The palette is borrowed from `image_playground`'s `--ip-*`
  # tokens so the two apps feel like one product. We add a light
  # variant alongside the dark one — the host page picks one via
  # `data-theme="light"` / `data-theme="dark"` on `<html>`. With
  # no attribute set, `prefers-color-scheme` decides at the
  # browser level.

  @css """
  :root {
    /* Defaults are the light theme; dark is overridden by
       [data-theme=dark] and by prefers-color-scheme when the
       user hasn't set an explicit preference. */
    --mi-bg:           #f7f8fa;
    --mi-surface:      #ffffff;
    --mi-surface-2:    #f1f3f6;
    --mi-border:       #e1e4ea;
    --mi-text:         #15181d;
    --mi-text-dim:     #4b5563;
    --mi-text-faint:   #6b7280;
    --mi-accent:       #2563eb;
    --mi-accent-soft:  rgba(37, 99, 235, 0.12);
    --mi-accent-strong:#1d4ed8;
    --mi-accent-fg:    #ffffff;
    --mi-error:        #b91c1c;
    --mi-error-bg:     #fef2f2;
    --mi-pill-bg:      #e5e7eb;
    --mi-pill-fg:      #374151;

    --mi-radius:       0.5rem;
    --mi-radius-sm:    0.375rem;
    --mi-radius-pill:  9999px;
    --mi-shadow-sm:    0 1px 2px rgba(15, 23, 42, 0.06);
    --mi-shadow-md:    0 4px 14px rgba(15, 23, 42, 0.08);
    --mi-mono:         ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  }

  [data-theme="dark"] {
    --mi-bg:           #0b0d10;
    --mi-surface:      #15181d;
    --mi-surface-2:    #1d2127;
    --mi-border:       #2a2f37;
    --mi-text:         #e5e7eb;
    --mi-text-dim:     #9ca3af;
    --mi-text-faint:   #6b7280;
    --mi-accent:       #60a5fa;
    --mi-accent-soft:  rgba(96, 165, 250, 0.16);
    --mi-accent-strong:#3b82f6;
    --mi-accent-fg:    #0b0d10;
    --mi-error:        #fca5a5;
    --mi-error-bg:     rgba(252, 165, 165, 0.12);
    --mi-pill-bg:      #2a2f37;
    --mi-pill-fg:      #e5e7eb;
    --mi-shadow-sm:    0 1px 2px rgba(0, 0, 0, 0.4);
    --mi-shadow-md:    0 4px 14px rgba(0, 0, 0, 0.35);
  }

  /* Track system preference when the user hasn't set explicit
     light/dark via the toggle. The :not([data-theme]) selector
     means "only fall through to system if no toggle choice
     persisted". */
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme]) {
      --mi-bg:           #0b0d10;
      --mi-surface:      #15181d;
      --mi-surface-2:    #1d2127;
      --mi-border:       #2a2f37;
      --mi-text:         #e5e7eb;
      --mi-text-dim:     #9ca3af;
      --mi-text-faint:   #6b7280;
      --mi-accent:       #60a5fa;
      --mi-accent-soft:  rgba(96, 165, 250, 0.16);
      --mi-accent-strong:#3b82f6;
      --mi-accent-fg:    #0b0d10;
      --mi-error:        #fca5a5;
      --mi-error-bg:     rgba(252, 165, 165, 0.12);
      --mi-pill-bg:      #2a2f37;
      --mi-pill-fg:      #e5e7eb;
      --mi-shadow-sm:    0 1px 2px rgba(0, 0, 0, 0.4);
      --mi-shadow-md:    0 4px 14px rgba(0, 0, 0, 0.35);
    }
  }

  * { box-sizing: border-box; }

  html, body {
    margin: 0;
    background: var(--mi-bg);
    color: var(--mi-text);
    font: 14px/1.55 ui-sans-serif, system-ui, -apple-system, "Segoe UI",
                   Roboto, "Helvetica Neue", Arial, sans-serif;
    transition: background 120ms ease, color 120ms ease;
  }

  /* ── Header ────────────────────────────────────────────── */

  .mi-header {
    background: var(--mi-surface);
    border-bottom: 1px solid var(--mi-border);
    padding: 1.25rem 2rem 0;
  }
  .mi-header-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1.5rem;
    margin-bottom: 1rem;
  }
  .mi-brand {
    text-decoration: none;
    color: inherit;
    display: inline-flex;
    align-items: center;
    gap: 0.85rem;
  }
  .mi-brand-text { display: flex; flex-direction: column; }
  .mi-logo {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    flex: 0 0 auto;
    box-shadow: var(--mi-shadow-sm);
  }
  .mi-brand h1 {
    font-size: 1.25rem;
    margin: 0 0 0.15rem;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  .mi-brand p { color: var(--mi-text-dim); margin: 0; font-size: 0.85rem; }

  .mi-tabs { display: flex; gap: 0.25rem; }
  .mi-tabs a {
    text-decoration: none;
    padding: 0.55rem 1rem;
    color: var(--mi-text-dim);
    border-bottom: 2px solid transparent;
    font-weight: 500;
    font-size: 0.9rem;
    transition: color 120ms ease, border-color 120ms ease;
  }
  .mi-tabs a.active {
    color: var(--mi-accent);
    border-bottom-color: var(--mi-accent);
  }
  .mi-tabs a:hover { color: var(--mi-text); }

  /* ── Theme toggle (segmented control, 3 states) ────────── */

  .mi-theme-toggle {
    position: relative;
    display: inline-flex;
    align-items: center;
    background: var(--mi-surface-2);
    border: 1px solid var(--mi-border);
    border-radius: var(--mi-radius-pill);
    padding: 2px;
    gap: 0;
  }
  .mi-theme-toggle button {
    position: relative;
    z-index: 1;
    border: 0;
    background: transparent;
    color: var(--mi-text-dim);
    font: inherit;
    cursor: pointer;
    padding: 0.3rem 0.6rem;
    border-radius: var(--mi-radius-pill);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 1.75rem;
    transition: color 120ms ease;
  }
  .mi-theme-toggle button:hover { color: var(--mi-text); }
  .mi-theme-toggle button[aria-pressed="true"] {
    color: var(--mi-text);
  }
  .mi-theme-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: calc((100% - 4px) / 3);
    height: calc(100% - 4px);
    background: var(--mi-surface);
    border-radius: var(--mi-radius-pill);
    box-shadow: var(--mi-shadow-sm);
    transition: transform 180ms cubic-bezier(0.4, 0, 0.2, 1);
    pointer-events: none;
  }
  .mi-theme-toggle[data-active="system"] .mi-theme-toggle-thumb { transform: translateX(0%); }
  .mi-theme-toggle[data-active="light"]  .mi-theme-toggle-thumb { transform: translateX(100%); }
  .mi-theme-toggle[data-active="dark"]   .mi-theme-toggle-thumb { transform: translateX(200%); }
  @media (prefers-reduced-motion: reduce) {
    .mi-theme-toggle-thumb { transition: none; }
    html, body { transition: none; }
  }
  .mi-theme-toggle svg {
    width: 14px;
    height: 14px;
    stroke: currentColor;
    fill: none;
    stroke-width: 2;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  /* ── Main content ──────────────────────────────────────── */

  .mi-main {
    max-width: 60rem;
    margin: 0 auto;
    padding: 2rem;
  }

  .mi-error {
    background: var(--mi-error-bg);
    color: var(--mi-error);
    border: 1px solid var(--mi-error);
    padding: 0.75rem 1rem;
    border-radius: var(--mi-radius);
    margin-bottom: 1rem;
  }

  /* Cards (panels) — borrowed from image_playground's .ip-card */
  .mi-card {
    background: var(--mi-surface);
    border: 1px solid var(--mi-border);
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 1.25rem;
    box-shadow: var(--mi-shadow-sm);
  }
  .mi-card h2 {
    font-size: 1rem;
    margin: 0 0 0.25rem;
    font-weight: 600;
    letter-spacing: -0.005em;
  }
  .mi-card p.mi-desc {
    color: var(--mi-text-dim);
    margin: 0 0 1.25rem;
    font-size: 0.9rem;
    max-width: 60ch;
  }

  /* ── Forms ─────────────────────────────────────────────── */

  form.mi-form {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem 1.25rem;
    margin-bottom: 1rem;
  }
  form.mi-form .mi-field-wide { grid-column: 1 / -1; }
  form.mi-form .mi-actions {
    grid-column: 1 / -1;
    display: flex;
    gap: 0.5rem;
    align-items: center;
    margin-top: 0.25rem;
  }

  .mi-field { display: flex; flex-direction: column; gap: 0.25rem; }
  .mi-field label {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    font-size: 0.7rem;
    color: var(--mi-text-dim);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
  /* Don't use `font: inherit` here — the outer <label> sets
     a tiny-uppercase style that would propagate into <select>,
     and several browsers (Firefox especially) ship a serif
     default for <option>. Spell out every property the label
     might have touched so the control reads correctly. */
  .mi-field input[type="text"],
  .mi-field input[type="search"],
  .mi-field select,
  .mi-field textarea,
  .mi-field select option {
    font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont,
                 "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    font-size: 0.9rem;
    font-weight: 400;
    font-style: normal;
    text-transform: none;
    letter-spacing: normal;
  }

  .mi-field input[type="text"],
  .mi-field input[type="search"],
  .mi-field select,
  .mi-field textarea {
    padding: 0.45rem 0.7rem;
    border: 1px solid var(--mi-border);
    border-radius: var(--mi-radius-sm);
    background: var(--mi-surface-2);
    color: var(--mi-text);
    line-height: 1.4;
  }

  /* On most browsers the <option> popup is rendered by the OS
     and only respects a handful of CSS properties. Set what we
     can — colour + background so it tracks the theme — and
     accept that the OS may override the rest. */
  .mi-field select option {
    background: var(--mi-surface);
    color: var(--mi-text);
  }
  .mi-field input:focus, .mi-field select:focus {
    outline: none;
    border-color: var(--mi-accent);
    box-shadow: 0 0 0 3px var(--mi-accent-soft);
  }
  .mi-checkbox {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    color: var(--mi-text);
    text-transform: none;
    letter-spacing: 0;
    font-weight: normal;
  }
  .mi-checkbox input[type="checkbox"] { accent-color: var(--mi-accent); }
  .mi-hint {
    color: var(--mi-text-faint);
    font-size: 0.78rem;
    text-transform: none;
    letter-spacing: 0;
    font-weight: normal;
  }

  button.mi-btn {
    font: inherit;
    background: var(--mi-accent);
    color: var(--mi-accent-fg);
    border: none;
    padding: 0.55rem 1.25rem;
    border-radius: var(--mi-radius-sm);
    cursor: pointer;
    font-weight: 600;
    font-size: 0.9rem;
    transition: background 120ms ease;
  }
  button.mi-btn:hover { background: var(--mi-accent-strong); }
  button.mi-btn:focus-visible {
    outline: 2px solid var(--mi-accent);
    outline-offset: 2px;
  }

  /* ── Result lists / tables ──────────────────────────────── */

  .mi-result {
    display: grid;
    grid-template-columns: 12rem 1fr;
    gap: 0.45rem 1rem;
    background: var(--mi-surface-2);
    padding: 1rem 1.25rem;
    border-radius: var(--mi-radius);
    font-size: 0.9rem;
  }
  .mi-result dt {
    color: var(--mi-text-dim);
    font-weight: 500;
    font-size: 0.78rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding-top: 0.2rem;
  }
  .mi-result dd { margin: 0; font-family: var(--mi-mono); }
  .mi-result dd.mi-bad { color: var(--mi-error); }

  table.mi-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 0.5rem;
    font-size: 0.9rem;
  }
  table.mi-table th, table.mi-table td {
    padding: 0.5rem 0.75rem;
    text-align: left;
    border-bottom: 1px solid var(--mi-border);
    vertical-align: top;
  }
  table.mi-table th {
    background: var(--mi-surface-2);
    font-weight: 600;
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--mi-text-dim);
  }
  table.mi-table td.mi-mono { font-family: var(--mi-mono); }
  table.mi-table td.mi-bad  { color: var(--mi-error); }

  .mi-code {
    background: var(--mi-surface-2);
    color: var(--mi-text);
    padding: 1rem 1.25rem;
    border-radius: var(--mi-radius);
    margin: 0;
    font-family: var(--mi-mono);
    font-size: 0.82rem;
    line-height: 1.55;
    overflow-x: auto;
  }

  code, .mi-code-inline {
    font-family: var(--mi-mono);
    background: var(--mi-surface-2);
    padding: 0.1rem 0.35rem;
    border-radius: 0.25rem;
    font-size: 0.85em;
  }

  .mi-pill {
    display: inline-block;
    background: var(--mi-pill-bg);
    color: var(--mi-pill-fg);
    padding: 0.1rem 0.55rem;
    border-radius: var(--mi-radius-pill);
    font-size: 0.7rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-left: 0.4rem;
  }

  /* ── Theming the embedded components ────────────────────── */
  /* The components ship their own CSS file via @import — these
     overrides bind the components to the visualizer's theme so
     they switch with the page. */

  .money-input-wrapper {
    background: var(--mi-surface-2);
    border-color: var(--mi-border);
  }
  .money-input-wrapper:focus-within {
    border-color: var(--mi-accent);
    outline-color: var(--mi-accent);
    box-shadow: 0 0 0 3px var(--mi-accent-soft);
  }
  .money-input-field { color: var(--mi-text); background: transparent; }
  .money-input-symbol {
    background: var(--mi-surface);
    color: var(--mi-text);
    border-color: var(--mi-border);
  }
  .currency-picker-trigger {
    background: var(--mi-surface);
    color: var(--mi-text);
  }
  .currency-picker-trigger:hover { background: var(--mi-surface-2); }
  .currency-picker-overlay {
    background: var(--mi-surface);
    border-color: var(--mi-border);
    color: var(--mi-text);
    box-shadow: var(--mi-shadow-md);
  }
  .currency-picker-search-row { border-color: var(--mi-border); }
  .currency-picker-search {
    background: var(--mi-surface-2);
    color: var(--mi-text);
    border-color: var(--mi-border);
  }
  .currency-picker-search:focus {
    outline: none;
    border-color: var(--mi-accent);
    box-shadow: 0 0 0 3px var(--mi-accent-soft);
  }
  .currency-picker-section { color: var(--mi-text-dim); }
  .currency-picker-row:hover { background: var(--mi-accent-soft); }
  .currency-picker-row[aria-selected="true"] {
    background: var(--mi-accent);
    color: var(--mi-accent-fg);
  }
  .currency-picker-row-symbol { color: var(--mi-text-faint); }
  .currency-picker-empty { color: var(--mi-text-dim); }

  /* ── Footer ────────────────────────────────────────────── */

  .mi-footer {
    margin-top: 3rem;
    color: var(--mi-text-faint);
    font-size: 0.82rem;
    text-align: center;
  }
  """

  @doc "Returns the visualizer's CSS as a binary."
  @spec css() :: String.t()
  def css, do: @css

  @external_resource Path.join(:code.priv_dir(:money_input), "static/money_input.css")
  @external_resource Path.join(:code.priv_dir(:money_input), "static/money_input.js")
  @external_resource Path.join(:code.priv_dir(:money_input), "static/money.png")

  @money_input_css File.read!(Path.join(:code.priv_dir(:money_input), "static/money_input.css"))
  @money_input_js File.read!(Path.join(:code.priv_dir(:money_input), "static/money_input.js"))
  @money_logo_png File.read!(Path.join(:code.priv_dir(:money_input), "static/money.png"))

  @doc "Returns the component CSS shipped in priv/static."
  @spec money_input_css() :: String.t()
  def money_input_css, do: @money_input_css

  @doc "Returns the JS hooks shipped in priv/static."
  @spec money_input_js() :: String.t()
  def money_input_js, do: @money_input_js

  @doc """
  Returns the binary PNG bytes of the Money library's logo.

  Compiled into the BEAM at build time so the visualizer and
  any wrapper app (e.g. `money_input_playground`) can serve it
  without a separate static-files plug.
  """
  @spec logo_png() :: binary()
  def logo_png, do: @money_logo_png
end
