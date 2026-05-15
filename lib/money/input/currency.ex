defmodule Money.Input.Currency do
  @moduledoc """
  Currency + locale display data for money input components.

  Given a locale and a currency, returns the data a UI needs to
  render a currency-aware input correctly: the locale's
  number-system separators, the currency symbol resolved per
  CLDR rules, the symbol's position relative to the digits (read
  from the locale's currency format pattern, not guessed), and
  the currency's fractional-digit precision.

  All locale lookups go through `Localize.validate_locale/1`;
  the resulting `t:Localize.LanguageTag.t/0`'s
  `:cldr_locale_id` is the canonical id we report back. Number
  system resolution goes through
  `Localize.Number.System.number_system_from_locale/1` so
  Arabic-Indic, Persian, and other non-Latin digit systems are
  handled correctly (no assumption of `:latn`).

  """

  alias Localize.Currency, as: LocalizeCurrency
  alias Localize.LanguageTag
  alias Localize.Number.Format
  alias Localize.Number.Symbol
  alias Localize.Number.System
  alias Money.Input.NoNumberSymbolsError

  @typedoc """
  Locale + currency display data resolved by
  `currency_for_locale/2`.

  * `:locale` — the canonical CLDR locale id (atom).

  * `:language_tag` — the full `t:Localize.LanguageTag.t/0` for
    callers needing access to extensions, regions, scripts, etc.

  * `:number_system` — the active number system (`:latn`,
    `:arab`, `:arabext`, …).

  * `:decimal` — the locale's decimal separator character.

  * `:group` — the locale's grouping separator character.

  * `:minus_sign` — the locale's minus sign character.

  * `:currency` — a `t:Localize.Currency.t/0` for the requested
    currency, or `nil` when no currency was supplied.

  * `:symbol` — the currency symbol resolved per
    `Localize.Currency.symbol/2` (kind selected via the
    `:symbol_kind` option). `nil` when no currency was supplied.

  * `:symbol_position` — `:prefix` or `:suffix`, derived from
    the locale's CLDR currency format pattern. `nil` when no
    currency was supplied.

  * `:iso_digits` — the currency's ISO 4217 fractional digit
    count (USD: 2, JPY: 0, BHD: 3). `nil` when no currency.

  """
  @type t :: %__MODULE__{
          locale: atom(),
          language_tag: LanguageTag.t(),
          number_system: atom(),
          decimal: String.t(),
          group: String.t(),
          minus_sign: String.t(),
          currency: LocalizeCurrency.t() | nil,
          symbol: String.t() | nil,
          symbol_position: :prefix | :suffix | nil,
          iso_digits: non_neg_integer() | nil
        }

  defstruct [
    :locale,
    :language_tag,
    :number_system,
    :decimal,
    :group,
    :minus_sign,
    :currency,
    :symbol,
    :symbol_position,
    :iso_digits
  ]

  @currency_indicator "¤"
  @digit_indicators ["#", "0", "@"]

  @doc """
  Resolves currency and locale display data for the given
  locale (and optional currency).

  ### Arguments

  * `locale` is a locale identifier (atom, string, or
    `t:Localize.LanguageTag.t/0`). Defaults to
    `Localize.get_locale/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:currency` — an ISO 4217 currency code (atom or string).
    When given, currency-specific fields (`:currency`,
    `:symbol`, `:symbol_position`, `:iso_digits`) are populated.
    When omitted, those fields are `nil`.

  * `:symbol_kind` — which currency-marker variant to surface as
    `:symbol`. One of `:standard` (default), `:symbol`,
    `:narrow`, `:iso`, `:none`. Forwarded to
    `Localize.Currency.symbol/2`.

  ### Returns

  * `{:ok, t()}` on success.

  * `{:error, Exception.t()}` when the locale can't be parsed,
    the number system can't be resolved, number symbols are
    missing for the locale, or the currency code is unknown.

  ### Examples

      iex> {:ok, info} = Money.Input.Currency.currency_for_locale(:en, currency: :USD)
      iex> {info.decimal, info.group, info.symbol, info.symbol_position, info.iso_digits}
      {".", ",", "$", :prefix, 2}

      iex> {:ok, info} = Money.Input.Currency.currency_for_locale(:de, currency: :EUR)
      iex> {info.decimal, info.group, info.symbol, info.symbol_position}
      {",", ".", "€", :suffix}

      iex> {:ok, info} = Money.Input.Currency.currency_for_locale(:ja, currency: :JPY)
      iex> info.iso_digits
      0

  """
  @spec currency_for_locale(LanguageTag.t() | atom() | String.t() | nil, Keyword.t()) ::
          {:ok, t()} | {:error, Exception.t()}
  def currency_for_locale(locale \\ nil, options \\ []) do
    currency_code = Keyword.get(options, :currency)
    symbol_kind = Keyword.get(options, :symbol_kind, :standard)

    with {:ok, language_tag} <- Localize.validate_locale(locale || Localize.get_locale()),
         {:ok, number_system} <- System.number_system_from_locale(language_tag),
         {:ok, symbols} <- resolve_symbols(language_tag, number_system),
         {:ok, currency} <- resolve_currency(currency_code, language_tag),
         {:ok, symbol_position} <- resolve_symbol_position(currency, language_tag, number_system),
         {:ok, symbol} <- resolve_symbol(currency, symbol_kind) do
      {:ok,
       %__MODULE__{
         locale: language_tag.cldr_locale_id,
         language_tag: language_tag,
         number_system: number_system,
         decimal: symbol_string(symbols.decimal),
         group: symbol_string(symbols.group),
         minus_sign: symbol_string(symbols.minus_sign),
         currency: currency,
         symbol: symbol,
         symbol_position: symbol_position,
         iso_digits: currency && currency.iso_digits
       }}
    end
  end

  # ── locale + number system → symbols ───────────────────────

  defp resolve_symbols(language_tag, number_system) do
    case Symbol.number_symbols_for(language_tag, number_system) do
      {:ok, symbols} ->
        {:ok, symbols}

      {:error, _} ->
        default_number_system_symbols(language_tag, number_system)
    end
  end

  # CLDR doesn't always populate symbols for every
  # (locale, system) pair. Fall back to the locale's
  # *default* number system — the value at the `:default`
  # key of `Localize.Number.System.number_systems_for/1`
  # (e.g. `:latn` for `en`, `:arabext` for `fa`).
  defp default_number_system_symbols(language_tag, number_system) do
    with {:ok, %{default: default_system}} <- System.number_systems_for(language_tag),
         true <- default_system != number_system,
         {:ok, symbols} <- Symbol.number_symbols_for(language_tag, default_system) do
      {:ok, symbols}
    else
      _ ->
        {:error,
         NoNumberSymbolsError.exception(
           locale: language_tag.cldr_locale_id,
           number_system: number_system
         )}
    end
  end

  # Number-symbol fields are either a plain binary or a map of
  # variants keyed by `:standard` / `:accounting` / etc. Every
  # locale CLDR ships has one of these two shapes (verified
  # empirically across ~70 locales). If a new shape ever appears
  # we want a loud `FunctionClauseError` so it surfaces rather
  # than silently returning garbage from `Map.values/1`.
  defp symbol_string(value) when is_binary(value), do: value
  defp symbol_string(%{standard: value}) when is_binary(value), do: value

  # ── currency resolution ────────────────────────────────────

  defp resolve_currency(nil, _language_tag), do: {:ok, nil}

  defp resolve_currency(code, language_tag) do
    LocalizeCurrency.currency_for_code(code, locale: language_tag)
  end

  # ── symbol position from the CLDR format pattern ──────────
  #
  # The pattern looks like `¤#,##0.00` (prefix) or `#,##0.00 ¤`
  # (suffix). Find where the `¤` placeholder sits relative to
  # the first digit placeholder (`#`, `0`, or `@`). No locale
  # heuristics, no hardcoded list — CLDR is the source of truth.

  defp resolve_symbol_position(nil, _language_tag, _number_system) do
    {:ok, nil}
  end

  defp resolve_symbol_position(_currency, language_tag, number_system) do
    with {:ok, formats} <- Format.formats_for(language_tag, number_system),
         %{currency: pattern} when is_binary(pattern) <- formats do
      {:ok, position_in_pattern(pattern)}
    end
  end

  defp position_in_pattern(pattern) do
    cond do
      currency_position(pattern) <= digit_position(pattern) -> :prefix
      true -> :suffix
    end
  end

  defp currency_position(pattern) do
    case :binary.match(pattern, @currency_indicator) do
      {pos, _} -> pos
      :nomatch -> -1
    end
  end

  defp digit_position(pattern) do
    @digit_indicators
    |> Enum.map(&:binary.match(pattern, &1))
    |> Enum.flat_map(fn
      {pos, _} -> [pos]
      :nomatch -> []
    end)
    |> Enum.min(fn -> -1 end)
  end

  # ── currency symbol selection ──────────────────────────────

  defp resolve_symbol(nil, _kind), do: {:ok, nil}

  defp resolve_symbol(%LocalizeCurrency{} = currency, kind),
    do: LocalizeCurrency.symbol(currency, kind)
end
