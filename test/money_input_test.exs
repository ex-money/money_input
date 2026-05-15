defmodule Money.InputTest do
  use ExUnit.Case
  doctest Money.Input
  doctest Money.Input.Parser
  doctest Money.Input.Cast
  doctest Money.Input.Formatter
  doctest Money.Input.Validator
  doctest Money.Input.Locale

  describe "Parser.parse_number/2" do
    test "parses en locale conventions" do
      assert {:ok, decimal} = Money.Input.Parser.parse_number("1,234.56", locale: :en)
      assert Decimal.equal?(decimal, Decimal.new("1234.56"))
    end

    test "parses de locale (inverted separators)" do
      assert {:ok, decimal} = Money.Input.Parser.parse_number("1.234,56", locale: :de)
      assert Decimal.equal?(decimal, Decimal.new("1234.56"))
    end

    test "blank input is nil" do
      assert {:ok, nil} = Money.Input.Parser.parse_number("", locale: :en)
      assert {:ok, nil} = Money.Input.Parser.parse_number(nil, locale: :en)
    end

    test "accounting parens become negative" do
      assert {:ok, decimal} = Money.Input.Parser.parse_number("(1,234.56)", locale: :en)
      assert Decimal.equal?(decimal, Decimal.new("-1234.56"))
    end

    test "tolerates NBSP grouping" do
      # fr uses NBSP grouping. Paste from a Word doc may use NBSP
      # already which is what fr expects natively.
      assert {:ok, decimal} = Money.Input.Parser.parse_number("1 234,56", locale: :fr)
      assert Decimal.equal?(decimal, Decimal.new("1234.56"))
    end
  end

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
      assert {:error, {Money.UnknownCurrencyError, _}} =
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

    test "delegates strings to parse_money for convenience" do
      assert {:ok, %Money{currency: :USD} = money} =
               Money.Input.Cast.cast("$1,234.56", locale: :en)

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end
  end

  describe "Parser.parse_money/2" do
    test "parses currency symbols" do
      assert {:ok, %Money{currency: :USD} = money} =
               Money.Input.Parser.parse_money("$1,234.56", locale: :en)

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "uses provided default currency" do
      assert {:ok, %Money{currency: :EUR} = money} =
               Money.Input.Parser.parse_money("1.234,56", locale: :de, currency: :EUR)

      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "blank input is nil" do
      assert {:ok, nil} = Money.Input.Parser.parse_money("", locale: :en, currency: :USD)
    end
  end

  describe "Parser.to_canonical/1" do
    test "decimals stringify to period form" do
      assert Money.Input.Parser.to_canonical(Decimal.new("1234.56")) == "1234.56"
    end

    test "money stringifies to canonical decimal" do
      assert Money.Input.Parser.to_canonical(Money.new(:USD, "1234.56")) == "1234.56"
    end
  end

  describe "Formatter.format_number/2" do
    test "en uses period decimal" do
      assert Money.Input.Formatter.format_number(Decimal.new("1234.56"), locale: :en) ==
               "1,234.56"
    end

    test "de uses comma decimal" do
      assert Money.Input.Formatter.format_number(Decimal.new("1234.56"), locale: :de) ==
               "1.234,56"
    end
  end

  describe "Formatter.format_money/2" do
    test "renders currency symbol" do
      assert Money.Input.Formatter.format_money(Money.new(:USD, "1234.56"), locale: :en) ==
               "$1,234.56"
    end

    test "no_symbol returns only the digits" do
      assert Money.Input.Formatter.format_money(
               Money.new(:USD, "1234.56"),
               locale: :en,
               no_symbol: true
             ) == "1,234.56"
    end
  end

  describe "Validator.validate_number/2" do
    test "rejects values out of range" do
      assert {:error, [{:max, _}]} =
               Money.Input.Validator.validate_number(Decimal.new("100"), max: 50)

      assert {:error, [{:min, _}]} =
               Money.Input.Validator.validate_number(Decimal.new("1"), min: 5)
    end

    test "rejects excessive decimals" do
      assert {:error, [{:decimals, _}]} =
               Money.Input.Validator.validate_number(Decimal.new("1.234"), decimals: 2)
    end

    test "accepts nil unless required" do
      assert :ok = Money.Input.Validator.validate_number(nil)

      assert {:error, [{:required, _}]} =
               Money.Input.Validator.validate_number(nil, required: true)
    end
  end

  describe "Validator.validate_money/2" do
    test "rejects values that exceed the currency's iso digits" do
      assert {:error, [{:decimals, _}]} =
               Money.Input.Validator.validate_money(Money.new(:USD, "1.234"))

      # JPY has zero fractional digits.
      assert {:error, [{:decimals, _}]} =
               Money.Input.Validator.validate_money(Money.new(:JPY, "1.5"))
    end

    test "accepts BHD with three fractional digits" do
      assert :ok = Money.Input.Validator.validate_money(Money.new(:BHD, "1.234"))
    end

    test "rejects mismatched currency" do
      assert {:error, [{:currency, _}]} =
               Money.Input.Validator.validate_money(Money.new(:USD, 1), currency: :EUR)
    end
  end

  describe "Locale.resolve/2" do
    test "en uses period decimal, comma grouping" do
      assert {:ok, data} = Money.Input.Locale.resolve(:en, currency: :USD)
      assert data.decimal == "."
      assert data.group == ","
      assert data.symbol == "$"
      assert data.symbol_position == :prefix
    end

    test "de inverts separators and places symbol as suffix" do
      assert {:ok, data} = Money.Input.Locale.resolve(:de, currency: :EUR)
      assert data.decimal == ","
      assert data.group == "."
      assert data.symbol == "€"
      assert data.symbol_position == :suffix
    end

    test "JPY has zero iso digits" do
      assert {:ok, data} = Money.Input.Locale.resolve(:ja, currency: :JPY)
      assert data.iso_digits == 0
    end
  end
end
