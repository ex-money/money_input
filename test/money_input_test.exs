defmodule Money.InputTest do
  use ExUnit.Case
  doctest Money.Input
  doctest Money.Input.Cast
  doctest Money.Input.Validator
  doctest Money.Input.Currency

  describe "Cast.cast/2" do
    test "casts a nested form map into a Money.t" do
      assert {:ok, %Money{currency: :EUR} = money} =
               Money.Input.Cast.cast(
                 %{"amount" => "1.234,56", "currency" => "EUR"},
                 locale: :de
               )

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "falls back to :currency option when the map omits it" do
      assert {:ok, %Money{currency: :JPY}} =
               Money.Input.Cast.cast(%{"amount" => "10"}, currency: :JPY)
    end

    test "returns nil for blank amount" do
      assert {:ok, nil} = Money.Input.Cast.cast(%{"amount" => "", "currency" => "USD"})
      assert {:ok, nil} = Money.Input.Cast.cast(nil)
    end

    test "rejects map without currency or fallback" do
      assert {:error, %Money.UnknownCurrencyError{}} =
               Money.Input.Cast.cast(%{"amount" => "10"})
    end

    test "accepts atom-keyed map" do
      assert {:ok, %Money{currency: :USD}} =
               Money.Input.Cast.cast(%{amount: "10", currency: :USD})
    end

    test "round-trips a Money.t" do
      money = Money.new(:GBP, "5.00")
      assert {:ok, ^money} = Money.Input.Cast.cast(money)
    end

    test "delegates bare strings to Money.parse" do
      assert {:ok, %Money{currency: :USD} = money} =
               Money.Input.Cast.cast("$1,234.56", locale: :en)

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "string input uses :currency option as default_currency" do
      assert {:ok, %Money{currency: :EUR} = money} =
               Money.Input.Cast.cast("1.234,56", locale: :de, currency: :EUR)

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "blank string is nil" do
      assert {:ok, nil} = Money.Input.Cast.cast("", locale: :en, currency: :USD)
    end
  end

  describe "Validator.validate_money/2" do
    test "rejects values that exceed the currency's iso digits" do
      assert {:error, %Money.Input.ValidationError{errors: [{:decimals, _}]}} =
               Money.Input.Validator.validate_money(Money.new(:USD, "1.234"))

      # JPY has zero fractional digits.
      assert {:error, %Money.Input.ValidationError{errors: [{:decimals, _}]}} =
               Money.Input.Validator.validate_money(Money.new(:JPY, "1.5"))
    end

    test "accepts BHD with three fractional digits" do
      assert :ok = Money.Input.Validator.validate_money(Money.new(:BHD, "1.234"))
    end

    test "rejects mismatched currency" do
      assert {:error, %Money.Input.ValidationError{errors: [{:currency, _}]}} =
               Money.Input.Validator.validate_money(Money.new(:USD, 1), currency: :EUR)
    end
  end

  describe "Currency.currency_for_locale/2" do
    test "en uses period decimal, comma grouping, prefix symbol" do
      assert {:ok, data} = Money.Input.Currency.currency_for_locale(:en, currency: :USD)
      assert data.decimal == "."
      assert data.group == ","
      assert data.symbol == "$"
      assert data.symbol_position == :prefix
      assert data.iso_digits == 2
    end

    test "de inverts separators and places symbol as suffix" do
      assert {:ok, data} = Money.Input.Currency.currency_for_locale(:de, currency: :EUR)
      assert data.decimal == ","
      assert data.group == "."
      assert data.symbol == "€"
      assert data.symbol_position == :suffix
    end

    test "JPY has zero iso digits" do
      assert {:ok, data} = Money.Input.Currency.currency_for_locale(:ja, currency: :JPY)
      assert data.iso_digits == 0
    end

    test "uses the cldr_locale_id from the validated LanguageTag" do
      assert {:ok, data} =
               Money.Input.Currency.currency_for_locale("en-AU", currency: :AUD)

      # Canonical CLDR id (atom), not the raw input.
      assert is_atom(data.locale)
      assert data.language_tag.cldr_locale_id == data.locale
    end

    test "non-Latin number system: ar uses arab digits" do
      assert {:ok, data} = Money.Input.Currency.currency_for_locale("ar-EG", currency: :EGP)
      # Arabic locales use the :arab number system by default.
      assert data.number_system in [:arab, :latn]
    end

    test "symbol_kind: :none returns an empty string" do
      assert {:ok, data} =
               Money.Input.Currency.currency_for_locale(:en, currency: :USD, symbol_kind: :none)

      assert data.symbol == ""
    end

    test "symbol_kind: :iso returns the ISO code" do
      assert {:ok, data} =
               Money.Input.Currency.currency_for_locale(:en, currency: :USD, symbol_kind: :iso)

      assert data.symbol == "USD"
    end

    test "no currency → currency-specific fields are nil" do
      assert {:ok, data} = Money.Input.Currency.currency_for_locale(:en)
      assert data.currency == nil
      assert data.symbol == nil
      assert data.symbol_position == nil
      assert data.iso_digits == nil
      # number system + separators are still populated
      assert data.decimal == "."
      assert data.number_system == :latn
    end

    test "invalid locale returns a semantic exception" do
      assert {:error, %Localize.InvalidLocaleError{}} =
               Money.Input.Currency.currency_for_locale("xx-XX")
    end
  end
end
