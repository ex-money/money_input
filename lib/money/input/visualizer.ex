# `Money.Input.Visualizer` is a `Plug.Router`. It is only defined
# when `:plug` is available (i.e., when the consumer adds
# `{:plug, "~> 1.15"}` to their deps). When `:plug` isn't
# installed, the module simply doesn't exist — calling any
# function on it raises the standard `UndefinedFunctionError`,
# which is the conventional Elixir signal for "you're missing a
# dependency."
if Code.ensure_loaded?(Plug.Router) do
  defmodule Money.Input.Visualizer do
    @moduledoc """
    A web-based visualizer for `Money.Input`.

    This module is a `Plug.Router` that can be mounted inside a
    Phoenix or Plug application, or run standalone during
    development via `Money.Input.Visualizer.Standalone`.

    ## Views

    * `/input` — interactive number and money input demo. Pick
      a locale + currency, type a value, submit, and see the
      parsed `Decimal`/`Money`, the canonical wire form, the
      blur-formatted output, and validator results.

    * `/parse` — cross-locale parsing table. One input string,
      every locale, side-by-side.

    * `/format` — cross-locale formatting table. One parsed
      value, every locale, side-by-side.

    * `/locale` — locale display data: decimal/grouping
      separators, native digit system, currency-symbol position.
      This is the snapshot the JS hook would read from
      `data-` attributes.

    ## Mounting in Phoenix

    In your `router.ex`:

        forward "/money-input", Money.Input.Visualizer

    ## Running standalone

        Money.Input.Visualizer.Standalone.start(port: 4002)

    ## Optional dependencies

    The visualizer pulls in `:plug` (required for the router) and
    `:bandit` (only used by the standalone helper). Both are
    declared `optional: true` in this library's `mix.exs`, so you
    must add them to your own project's deps to use the
    visualizer:

        {:plug, "~> 1.15"},
        {:bandit, "~> 1.5"}

    ## Enable flag

    The visualizer module is always compiled when `:plug` is
    present, but `Money.Input.Visualizer.Standalone.start/1`
    refuses to start unless `:money_input, :visualizer` is set
    to `true` in config, or `enabled: true` is passed
    explicitly. Mounting under `forward/2` in a Phoenix router
    is not gated — the host app is the one who decided to
    expose it.

    """

    use Plug.Router

    plug(Plug.Logger, log: :debug)
    plug(:match)
    plug(Plug.Parsers, parsers: [:urlencoded], pass: ["text/*"])
    plug(:dispatch)

    alias Money.Input.Visualizer.Assets
    alias Money.Input.Visualizer.FormatView
    alias Money.Input.Visualizer.InputView
    alias Money.Input.Visualizer.LocaleView
    alias Money.Input.Visualizer.ParseView

    get "/" do
      base = base_path(conn)

      conn
      |> Plug.Conn.put_resp_header("location", base <> "/input")
      |> Plug.Conn.send_resp(302, "")
    end

    get "/input" do
      params = parse_params(conn.params, :input)
      html(conn, InputView.render(params, base_path(conn)))
    end

    get "/parse" do
      params = parse_params(conn.params, :parse)
      html(conn, ParseView.render(params, base_path(conn)))
    end

    get "/format" do
      params = parse_params(conn.params, :format)
      html(conn, FormatView.render(params, base_path(conn)))
    end

    get "/locale" do
      params = parse_params(conn.params, :locale)
      html(conn, LocaleView.render(params, base_path(conn)))
    end

    get "/assets/style.css" do
      conn
      |> Plug.Conn.put_resp_content_type("text/css")
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> Plug.Conn.send_resp(200, Assets.css())
    end

    get "/assets/money_input.css" do
      conn
      |> Plug.Conn.put_resp_content_type("text/css")
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> Plug.Conn.send_resp(200, Assets.money_input_css())
    end

    get "/assets/money_input.js" do
      conn
      |> Plug.Conn.put_resp_content_type("application/javascript")
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> Plug.Conn.send_resp(200, Assets.money_input_js())
    end

    match _ do
      send_resp(conn, 404, "Not found")
    end

    # ---- helpers ---------------------------------------------------------

    defp html(conn, iodata) do
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, IO.iodata_to_binary(iodata))
    end

    defp base_path(%Plug.Conn{script_name: []}), do: ""
    defp base_path(%Plug.Conn{script_name: segments}), do: "/" <> Enum.join(segments, "/")

    defp parse_params(params, :input) do
      %{
        locale: param_locale(params, "locale", "en"),
        default_currency: param_currency(params, "default_currency", "USD"),
        number_input: blank_default(Map.get(params, "number_input"), nil),
        money_input: blank_default(Map.get(params, "money_input"), nil),
        picker: picker_default(params),
        preferred_currencies: preferred_currencies(params)
      }
    end

    defp parse_params(params, :parse) do
      %{
        input: blank_default(Map.get(params, "input"), "1,234.56"),
        currency: param_currency(params, "currency", "USD"),
        mode: atom_default(Map.get(params, "mode"), [:number, :money], :number)
      }
    end

    defp parse_params(params, :format) do
      %{
        amount: blank_default(Map.get(params, "amount"), "1234567.89"),
        currency: param_currency(params, "currency", "USD"),
        mode: atom_default(Map.get(params, "mode"), [:number, :money], :money)
      }
    end

    defp parse_params(params, :locale) do
      %{
        currency: param_currency(params, "currency", "USD")
      }
    end

    defp param_locale(params, key, default) do
      case Map.get(params, key) do
        nil -> default
        "" -> default
        value when is_binary(value) -> value
      end
    end

    defp param_currency(params, key, default) do
      case Map.get(params, key) do
        nil ->
          to_atom_or(default, nil)

        "" ->
          nil

        value when is_binary(value) ->
          to_atom_or(value, to_atom_or(default, nil))
      end
    end

    defp to_atom_or(nil, fallback), do: fallback

    defp to_atom_or(value, fallback) when is_binary(value) do
      try do
        String.to_existing_atom(value)
      rescue
        ArgumentError -> fallback
      end
    end

    defp blank_default(nil, default), do: default
    defp blank_default("", default), do: default
    defp blank_default(value, _), do: value

    # Defaults the currency picker on. After a form submission we
    # trust whatever the checkbox sent (absent = unchecked = off);
    # on a fresh load (no `submitted` hidden field), we turn it on
    # so a developer landing on the visualizer sees the picker
    # immediately.
    defp picker_default(params) do
      if Map.has_key?(params, "submitted") do
        truthy?(Map.get(params, "picker"))
      else
        true
      end
    end

    defp preferred_currencies(params) do
      case Map.get(params, "preferred") do
        nil -> ~w(USD EUR GBP JPY CHF)a
        "" -> ~w(USD EUR GBP JPY CHF)a
        value when is_binary(value) -> parse_currency_list(value)
      end
    end

    defp parse_currency_list(value) do
      value
      |> String.split([",", " ", "\n"], trim: true)
      |> Enum.map(&String.upcase/1)
      |> Enum.map(&to_atom_or(&1, nil))
      |> Enum.reject(&is_nil/1)
    end

    defp truthy?(nil), do: false
    defp truthy?("0"), do: false
    defp truthy?("false"), do: false
    defp truthy?(""), do: false
    defp truthy?(_), do: true

    defp atom_default(nil, _allowed, default), do: default

    defp atom_default(value, allowed, default) when is_binary(value) do
      atom =
        try do
          String.to_existing_atom(value)
        rescue
          ArgumentError -> default
        end

      if atom in allowed, do: atom, else: default
    end

    defp atom_default(_, _, default), do: default
  end
end
