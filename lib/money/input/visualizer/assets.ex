defmodule Money.Input.Visualizer.Assets do
  @moduledoc false

  # Static assets for the visualizer. Inline CSS keeps the
  # visualizer dependency-free at the asset layer.

  @css """
  :root {
    --bg: #fafaf9;
    --fg: #1c1917;
    --muted: #78716c;
    --border: #e7e5e4;
    --accent: #047857;
    --accent-fg: #ecfdf5;
    --error: #b91c1c;
    --error-bg: #fef2f2;
    --code-bg: #f5f5f4;
    --pill: #d6d3d1;
  }

  * { box-sizing: border-box; }

  html, body {
    margin: 0;
    background: var(--bg);
    color: var(--fg);
    font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI",
                 Roboto, "Helvetica Neue", Arial, sans-serif;
    line-height: 1.5;
  }

  .mi-header {
    border-bottom: 1px solid var(--border);
    padding: 1.5rem 2rem 0;
    background: white;
  }
  .mi-brand { text-decoration: none; color: inherit; display: block; }
  .mi-brand h1 { font-size: 1.5rem; margin: 0 0 0.25rem; }
  .mi-brand p { color: var(--muted); margin: 0 0 1rem; }

  .mi-tabs { display: flex; gap: 0.25rem; }
  .mi-tabs a {
    text-decoration: none;
    padding: 0.5rem 1rem;
    color: var(--muted);
    border-bottom: 2px solid transparent;
    font-weight: 500;
  }
  .mi-tabs a.active {
    color: var(--accent);
    border-bottom-color: var(--accent);
  }
  .mi-tabs a:hover { color: var(--fg); }

  .mi-main {
    max-width: 56rem;
    margin: 0 auto;
    padding: 2rem;
  }

  .mi-error {
    background: var(--error-bg);
    color: var(--error);
    border: 1px solid var(--error);
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    margin-bottom: 1rem;
  }

  .mi-card {
    background: white;
    border: 1px solid var(--border);
    border-radius: 0.75rem;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
  }
  .mi-card h2 {
    font-size: 1.125rem;
    margin: 0 0 0.25rem;
  }
  .mi-card p.mi-desc {
    color: var(--muted);
    margin: 0 0 1.25rem;
    font-size: 0.95rem;
  }

  form.mi-form {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
    margin-bottom: 1rem;
  }
  form.mi-form .mi-field-wide { grid-column: 1 / -1; }
  form.mi-form .mi-actions {
    grid-column: 1 / -1;
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .mi-field { display: flex; flex-direction: column; gap: 0.25rem; }
  .mi-field label {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    font-size: 0.85rem;
    color: var(--muted);
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .mi-field input, .mi-field select, .mi-field textarea {
    font: inherit;
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--border);
    border-radius: 0.375rem;
    background: white;
    color: var(--fg);
  }
  .mi-field input:focus, .mi-field select:focus {
    outline: 2px solid var(--accent);
    outline-offset: -1px;
    border-color: var(--accent);
  }
  .mi-hint { color: var(--muted); font-size: 0.8rem; }

  button.mi-btn {
    font: inherit;
    background: var(--accent);
    color: var(--accent-fg);
    border: none;
    padding: 0.55rem 1.25rem;
    border-radius: 0.375rem;
    cursor: pointer;
    font-weight: 600;
  }
  button.mi-btn:hover { filter: brightness(0.95); }

  .mi-money-input-wrapper {
    display: inline-flex;
    align-items: stretch;
    border: 1px solid var(--border);
    border-radius: 0.5rem;
    background: white;
    overflow: hidden;
    font-size: 1.25rem;
    min-width: 16rem;
  }
  .mi-money-input-wrapper:focus-within {
    outline: 2px solid var(--accent);
    outline-offset: -1px;
    border-color: var(--accent);
  }
  .mi-money-input-wrapper input {
    border: none;
    padding: 0.6rem 0.75rem;
    flex: 1;
    font: inherit;
    text-align: right;
    background: transparent;
  }
  .mi-money-input-wrapper input:focus { outline: none; }
  .mi-money-symbol {
    background: var(--code-bg);
    color: var(--fg);
    padding: 0.6rem 0.75rem;
    display: inline-flex;
    align-items: center;
    border-right: 1px solid var(--border);
    font-weight: 600;
    min-width: 2.5rem;
    justify-content: center;
  }
  .mi-money-symbol.suffix {
    border-right: none;
    border-left: 1px solid var(--border);
  }

  .mi-result {
    display: grid;
    grid-template-columns: 12rem 1fr;
    gap: 0.5rem 1rem;
    background: var(--code-bg);
    padding: 1rem;
    border-radius: 0.5rem;
    font-size: 0.95rem;
  }
  .mi-result dt { color: var(--muted); font-weight: 500; }
  .mi-result dd { margin: 0; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
  .mi-result dd.mi-bad { color: var(--error); }

  table.mi-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 0.5rem;
    font-size: 0.95rem;
  }
  table.mi-table th, table.mi-table td {
    padding: 0.5rem 0.75rem;
    text-align: left;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
  }
  table.mi-table th {
    background: var(--code-bg);
    font-weight: 600;
    font-size: 0.8rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--muted);
  }
  table.mi-table td.mi-mono {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  table.mi-table td.mi-bad { color: var(--error); }

  .mi-code {
    background: var(--code-bg);
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    margin: 0;
    font-size: 0.9rem;
    overflow-x: auto;
  }

  .mi-pill {
    display: inline-block;
    background: var(--pill);
    color: var(--fg);
    padding: 0.1rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .mi-footer {
    margin-top: 3rem;
    color: var(--muted);
    font-size: 0.85rem;
    text-align: center;
  }
  .mi-footer code {
    background: var(--code-bg);
    padding: 0.1rem 0.35rem;
    border-radius: 0.25rem;
  }

  .mi-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
    gap: 1rem;
  }
  .mi-grid .mi-card { margin-bottom: 0; }
  """

  @doc "Returns the visualizer's CSS as a binary."
  @spec css() :: String.t()
  def css, do: @css

  @external_resource Path.join(:code.priv_dir(:money_input), "static/money_input.css")
  @external_resource Path.join(:code.priv_dir(:money_input), "static/money_input.js")

  @money_input_css File.read!(Path.join(:code.priv_dir(:money_input), "static/money_input.css"))
  @money_input_js File.read!(Path.join(:code.priv_dir(:money_input), "static/money_input.js"))

  @doc "Returns the component CSS shipped in priv/static."
  @spec money_input_css() :: String.t()
  def money_input_css, do: @money_input_css

  @doc "Returns the JS hooks shipped in priv/static."
  @spec money_input_js() :: String.t()
  def money_input_js, do: @money_input_js
end
