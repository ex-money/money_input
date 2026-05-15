defmodule Money.Input.Locale do
  @moduledoc """
  Locale-derived display data for number and money inputs.

  The data returned here is what an as-you-type JS formatter needs
  to render a number in the user's locale — decimal and grouping
  separator characters, native digit system, currency-symbol
  position. It is intentionally a *snapshot* of the locale's
  conventions, not a runtime parser; the parser delegates to
  `Localize.Number.Parser.parse/2` and `Money.parse/2`.

  """

  alias Localize.Number.Symbol

  @typedoc """
  Display data for a locale + optional currency combination.

  * `:locale` — the language tag the data was resolved for.

  * `:decimal` — the locale's decimal separator (e.g. `"."`,
    `","`, `"٫"`).

  * `:group` — the locale's grouping separator (e.g. `","`,
    `"."`, NBSP).

  * `:digit_system` — the native digit system (`:latn`, `:arab`,
    `:arabext`).

  * `:minus_sign` — the locale's minus sign character.

  * `:currency` — `nil` for plain numbers, otherwise the resolved
    `Localize.Currency.t/0` struct for the currency.

  * `:symbol` — the currency display symbol (e.g. `"$"`, `"€"`).

  * `:symbol_position` — `:prefix` or `:suffix`. Where the currency
    symbol sits relative to the number for this locale.

  * `:iso_digits` — number of fractional digits the currency
    requires (USD: 2, JPY: 0, BHD: 3).

  """
  @type t :: %__MODULE__{
          locale: atom() | String.t(),
          decimal: String.t(),
          group: String.t(),
          digit_system: atom(),
          minus_sign: String.t(),
          currency: Localize.Currency.t() | nil,
          symbol: String.t() | nil,
          symbol_position: :prefix | :suffix | nil,
          iso_digits: non_neg_integer() | nil
        }

  defstruct [
    :locale,
    :decimal,
    :group,
    :digit_system,
    :minus_sign,
    :currency,
    :symbol,
    :symbol_position,
    :iso_digits
  ]

  @doc """
  Resolves display data for a locale and optional currency.

  ### Arguments

  * `locale` is a locale identifier (atom or string). Defaults
    to `Localize.get_locale/0`.

  * `options` is a keyword list.

  ### Options

  * `:currency` — an ISO currency code atom (e.g. `:USD`). When
    given, currency-specific fields are populated.

  * `:symbol_kind` — one of `:symbol` (default), `:narrow`, or
    `:iso`. Selects which currency marker to display.

  ### Returns

  * `{:ok, t()}` on success.

  * `{:error, Exception.t()}` when the locale or currency cannot
    be resolved.

  ### Examples

      iex> {:ok, locale_data} = Money.Input.Locale.resolve(:en)
      iex> locale_data.decimal
      "."

      iex> {:ok, locale_data} = Money.Input.Locale.resolve(:de, currency: :EUR)
      iex> {locale_data.decimal, locale_data.group, locale_data.symbol}
      {",", ".", "€"}

  """
  @spec resolve(atom() | String.t() | nil, Keyword.t()) :: {:ok, t()} | {:error, Exception.t()}
  def resolve(locale \\ nil, options \\ []) do
    locale = locale || Localize.get_locale()
    currency_code = Keyword.get(options, :currency)
    symbol_kind = Keyword.get(options, :symbol_kind, :symbol)

    with {:ok, language_tag} <- Localize.validate_locale(locale),
         {:ok, symbols_map} <- Symbol.number_symbols_for(language_tag),
         {:ok, symbols} <- pick_symbols(symbols_map),
         {:ok, currency} <- resolve_currency(currency_code, language_tag) do
      {:ok,
       %__MODULE__{
         locale: language_tag.canonical_locale_id || locale,
         decimal: symbol_string(symbols.decimal),
         group: symbol_string(symbols.group),
         digit_system: digit_system(symbols_map),
         minus_sign: symbol_string(symbols.minus_sign),
         currency: currency,
         symbol: currency_symbol(currency, symbol_kind),
         symbol_position: symbol_position(language_tag),
         iso_digits: currency && currency.iso_digits
       }}
    end
  end

  defp pick_symbols(symbols_map) when map_size(symbols_map) == 0 do
    {:error, RuntimeError.exception("no number symbols available for locale")}
  end

  defp pick_symbols(symbols_map) do
    case Map.get(symbols_map, :latn) do
      nil -> {:ok, symbols_map |> Map.values() |> hd()}
      symbol -> {:ok, symbol}
    end
  end

  # Symbol fields can be either a string or a map of variants
  # (`%{standard: ".", currency: ".", ...}` in some locales). Pick
  # the standard variant when given a map; the JS hook only wants
  # one character either way.
  defp symbol_string(value) when is_binary(value), do: value
  defp symbol_string(%{standard: value}) when is_binary(value), do: value
  defp symbol_string(%{} = map), do: map |> Map.values() |> List.first() |> to_string()
  defp symbol_string(value), do: to_string(value)

  defp digit_system(symbols_map) do
    cond do
      Map.has_key?(symbols_map, :latn) -> :latn
      true -> symbols_map |> Map.keys() |> hd()
    end
  end

  defp resolve_currency(nil, _language_tag), do: {:ok, nil}

  defp resolve_currency(code, _language_tag) do
    case Money.Currency.currency_for_code(code) do
      {:ok, currency} -> {:ok, currency}
      {:error, _} -> {:ok, nil}
    end
  end

  defp currency_symbol(nil, _), do: nil
  defp currency_symbol(%{narrow_symbol: narrow}, :narrow) when is_binary(narrow), do: narrow
  defp currency_symbol(%{code: code}, :iso), do: to_string(code)
  defp currency_symbol(%{symbol: symbol}, _), do: symbol

  # CLDR encodes the position of the currency symbol in each
  # locale's currencyFormat pattern. We don't yet expose that
  # at a fine grain, so we use a coarse heuristic: locales that
  # CLDR codes as "suffix" (most European locales other than
  # English) put the symbol after the number; the rest put it
  # before. Override-by-attribute on the component is the
  # documented escape hatch when this is wrong.
  @suffix_locales ~w(de de-AT de-CH fr fr-FR fr-CH it it-CH es es-ES pt pt-PT pt-BR
                     nl nl-NL nl-BE fi fi-FI sv sv-SE nb nb-NO da da-DK pl pl-PL
                     cs cs-CZ sk sk-SK hu hu-HU ro ro-RO bg bg-BG el el-GR ru ru-RU
                     uk uk-UA tr tr-TR)a

  defp symbol_position(%Localize.LanguageTag{} = tag) do
    locale_id = tag.canonical_locale_id |> normalize_locale_id()
    base = locale_id |> String.split("-") |> hd() |> String.to_atom()
    full = String.to_atom(locale_id)

    cond do
      full in @suffix_locales -> :suffix
      base in @suffix_locales -> :suffix
      true -> :prefix
    end
  end

  defp normalize_locale_id(nil), do: "en"
  defp normalize_locale_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_locale_id(id) when is_binary(id), do: id
end
