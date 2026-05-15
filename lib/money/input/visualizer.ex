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
      params = parse_params(conn, :input)
      html(conn, InputView.render(params, base_path(conn)))
    end

    get "/parse" do
      params = parse_params(conn, :parse)
      html(conn, ParseView.render(params, base_path(conn)))
    end

    get "/format" do
      params = parse_params(conn, :format)
      html(conn, FormatView.render(params, base_path(conn)))
    end

    get "/locale" do
      params = parse_params(conn, :locale)
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

    get "/assets/logo.png" do
      conn
      |> Plug.Conn.put_resp_content_type("image/png")
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> Plug.Conn.send_resp(200, Assets.logo_png())
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

    defp parse_params(%Plug.Conn{} = conn, view), do: parse_params(conn.params, view, conn.assigns)

    defp parse_params(params, :input, assigns) do
      deployment_default = default_locale(assigns)
      locale = param_locale(params, "locale", deployment_default)

      %{
        locale: locale,
        deployment_default_locale: deployment_default,
        default_currency:
          param_currency(params, "default_currency", default_currency_for(locale)),
        money_input: blank_default(Map.get(params, "money_input"), nil),
        picker: picker_default(params),
        preferred_currencies: preferred_currencies(params)
      }
    end

    defp parse_params(params, :parse, assigns) do
      locale = param_locale(params, "locale", default_locale(assigns))

      %{
        input: blank_default(Map.get(params, "input"), "1,234.56"),
        currency: param_currency(params, "currency", default_currency_for(locale)),
        mode: atom_default(Map.get(params, "mode"), [:number, :money], :number)
      }
    end

    defp parse_params(params, :format, assigns) do
      locale = param_locale(params, "locale", default_locale(assigns))

      %{
        amount: blank_default(Map.get(params, "amount"), "1234567.89"),
        currency: param_currency(params, "currency", default_currency_for(locale)),
        mode: atom_default(Map.get(params, "mode"), [:number, :money], :money)
      }
    end

    defp parse_params(params, :locale, assigns) do
      locale = param_locale(params, "locale", default_locale(assigns))

      %{
        currency: param_currency(params, "currency", default_currency_for(locale))
      }
    end

    defp param_locale(params, key, default) do
      case Map.get(params, key) do
        nil ->
          default

        "" ->
          default

        value when is_binary(value) ->
          # Reject locales we can't load — the alternative is a 500
          # when the view layer tries to resolve symbols for an
          # unknown tag. Falling back keeps the visualizer alive.
          validate_locale(value) || default
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

    # Locale priority for the visualizer's defaults:
    #
    #   1. `?locale=…` URL param  — handled at the call site
    #      by `param_locale/3`.
    #
    #   2. `conn.assigns[:locale]` — what an upstream Phoenix
    #      locale plug (e.g. one calling `Localize.put_locale/1`
    #      based on the user's session) typically sets. In a
    #      forward-mounted visualizer this is the host app's
    #      idea of the current user's locale.
    #
    #   3. `Localize.get_locale/0` — the per-process or
    #      application-level default. Used in the standalone
    #      visualizer where no upstream plug runs.
    #
    # The visualizer requires zero configuration to run: `:en`
    # is always pre-compiled by Localize and resolves to USD,
    # so the default flow works out of the box. Other locales
    # need to be pre-compiled OR
    # `config :localize, allow_runtime_locale_download: true`,
    # but that's only relevant once the user picks an exotic
    # locale — and the helpers below degrade gracefully (no
    # crash, fall back to `:en`/USD) when an unavailable locale
    # arrives.
    defp default_locale(assigns) do
      # Assigns from a host plug may carry anything — validate
      # them before trusting. `Localize.get_locale/0` is the
      # final authority on "the default locale" (it's the
      # application-level or per-process default, never a hard-
      # coded value) so we don't validate it again or guard with
      # a hardcoded fallback like `"en"`.
      validate_locale(stringify_locale(assigns[:locale])) ||
        stringify_locale(safe_get_locale())
    end

    defp safe_get_locale do
      Localize.get_locale()
    rescue
      _ -> nil
    end

    defp stringify_locale(nil), do: nil
    defp stringify_locale(locale) when is_binary(locale), do: locale
    defp stringify_locale(locale) when is_atom(locale), do: Atom.to_string(locale)
    defp stringify_locale(%{canonical_locale_id: id}) when is_binary(id), do: id
    defp stringify_locale(_), do: nil

    # Confirm the locale is something Localize can resolve before
    # we hand it to the view layer. If validation fails (unknown
    # tag, download disabled, etc.) we return `nil` so the caller
    # falls through to the next priority level. This keeps the
    # visualizer alive when a host app passes a stale or exotic
    # locale via `conn.assigns[:locale]`.
    defp validate_locale(nil), do: nil

    defp validate_locale(locale) do
      case Localize.validate_locale(locale) do
        {:ok, _tag} -> locale
        _ -> nil
      end
    rescue
      _ -> nil
    end

    # Returns the locale's natural ISO 4217 tender as a string
    # (en-AU → "AUD", ja-JP → "JPY"). When the lookup misses for
    # the given locale, fall back through `Localize.get_locale/0`
    # rather than a hard-coded currency — "the default locale's
    # currency" is the right semantics, whatever that locale
    # happens to be in this deployment.
    defp default_currency_for(locale) do
      with :error <- lookup_currency(locale) do
        case lookup_currency(safe_get_locale()) do
          :error -> nil
          code -> code
        end
      end
    end

    defp lookup_currency(nil), do: :error

    defp lookup_currency(locale) do
      case Localize.Currency.current_currency_from_locale(locale) do
        {:ok, code} when is_atom(code) -> Atom.to_string(code)
        _ -> :error
      end
    rescue
      _ -> :error
    catch
      _, _ -> :error
    end

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
