defmodule Money.Input.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Money.Input.Components

  describe "money_input/1" do
    test "renders prefix symbol for en-US" do
      html =
        render_component(&Components.money_input/1, money_assigns(:price, default_currency: :USD))

      assert html =~ ~s(data-currency="USD")
      assert html =~ ~s(data-iso-digits="2")
      assert html =~ ~s(data-symbol-position="prefix")
      assert html =~ ~s($</span>)
    end

    test "renders suffix symbol for de" do
      html =
        render_component(
          &Components.money_input/1,
          money_assigns(:price, default_currency: :EUR, locale: "de")
        )

      assert html =~ ~s(data-symbol-position="suffix")
      # Euro symbol rendered on the right side
      assert html =~ "€</span>"
    end

    test "JPY has zero iso digits" do
      html =
        render_component(
          &Components.money_input/1,
          money_assigns(:price, default_currency: :JPY, locale: "ja")
        )

      assert html =~ ~s(data-iso-digits="0")
    end

    test "embeds currency picker when currency_picker is true" do
      html =
        render_component(
          &Components.money_input/1,
          money_assigns(:price, default_currency: :USD, currency_picker: true)
        )

      assert html =~ ~s(data-currency-picker)
      assert html =~ ~s(phx-hook="CurrencyPicker")
    end

    test "renders the canonical (no_symbol) value in the input" do
      html =
        render_component(&Components.money_input/1, money_assigns(:price, default_currency: :USD))

      # The form data has "1234.56" canonical; the rendered value
      # should be the locale-formatted number portion (no $ inside
      # the input — the $ is the adornment).
      assert html =~ ~s(value="1,234.56")
      refute html =~ ~s(value="$1,234.56")
    end

    test "amount and currency are submitted as nested fields" do
      html =
        render_component(&Components.money_input/1, money_assigns(:price, default_currency: :USD))

      assert html =~ ~s(name="demo[price][amount]")
      assert html =~ ~s(name="demo[price][currency]")
    end

    test "hidden currency input is present even with fixed currency (no picker)" do
      html =
        render_component(&Components.money_input/1, money_assigns(:price, default_currency: :EUR))

      # Hidden currency input — picker off, fixed currency. Server
      # still receives both keys, so Money.Ecto.Composite.Type
      # casts in one step.
      assert html =~ ~r/type="hidden"[^>]*name="demo\[price\]\[currency\]"[^>]*value="EUR"/
    end

    test "embedded picker uses the nested currency name" do
      html =
        render_component(
          &Components.money_input/1,
          money_assigns(:price, default_currency: :USD, currency_picker: true)
        )

      # Picker's hidden value input replaces the standalone one,
      # using the same nested name.
      assert html =~ ~s(name="demo[price][currency]")
      assert html =~ ~s(data-currency-picker-value)
    end

    test "extracts amount and currency from a Money.t value" do
      form =
        Phoenix.HTML.FormData.to_form(%{"price" => Money.new(:JPY, "12345")}, as: :demo)

      html =
        render_component(&Components.money_input/1, %{
          form: form,
          field: :price,
          locale: "ja"
        })

      assert html =~ ~s(data-currency="JPY")
      assert html =~ ~s(data-iso-digits="0")
      # JPY: 0 fractional digits, so "12345" not "12,345.00"
      assert html =~ ~s(value="12,345")
    end

    test "extracts amount and currency from a nested-map value" do
      form =
        Phoenix.HTML.FormData.to_form(
          %{"price" => %{"amount" => "9876.54", "currency" => "GBP"}},
          as: :demo
        )

      html =
        render_component(&Components.money_input/1, %{
          form: form,
          field: :price,
          locale: "en"
        })

      assert html =~ ~s(data-currency="GBP")
      assert html =~ ~s(value="9,876.54")
    end
  end

  describe "currency_picker/1" do
    test "renders trigger, search input, and the listbox" do
      html =
        render_component(&Components.currency_picker/1, %{
          current: :USD,
          preferred: [:USD, :EUR, :GBP]
        })

      assert html =~ ~s(currency-picker-trigger)
      assert html =~ ~s(currency-picker-search)
      assert html =~ ~s(role="listbox")
      assert html =~ ~s(data-code="USD")
      assert html =~ ~s(data-code="EUR")
      assert html =~ ~s(data-code="GBP")
    end

    test "marks the current row as aria-selected" do
      html =
        render_component(&Components.currency_picker/1, %{
          current: :EUR,
          preferred: [:USD, :EUR]
        })

      # The row with EUR data-code should be aria-selected
      assert html =~ ~r/data-code="EUR"[^>]*aria-selected="true"/
    end

    test "includes flag glyphs" do
      html = render_component(&Components.currency_picker/1, %{current: :USD, preferred: [:USD]})
      # 🇺🇸 = U+1F1FA U+1F1F8
      assert html =~ "🇺🇸"
    end
  end

  describe "changeset" do
    test "cast_money/3 turns a nested-map submission into a Money.t" do
      changeset =
        Ecto.Changeset.cast(
          {%{}, %{price: :map}},
          %{"price" => %{"amount" => "1.234,56", "currency" => "EUR"}},
          [:price]
        )

      changeset = Money.Input.Changeset.cast_money(changeset, :price, locale: :de)

      money = Ecto.Changeset.get_change(changeset, :price)
      assert money.currency == :EUR
      assert Decimal.equal?(money.amount, Decimal.new("1234.56"))
    end

    test "cast_money/3 falls back to :currency option when the map omits it" do
      changeset =
        Ecto.Changeset.cast(
          {%{}, %{price: :map}},
          %{"price" => %{"amount" => "10.00"}},
          [:price]
        )

      changeset =
        Money.Input.Changeset.cast_money(changeset, :price, locale: :en, currency: :JPY)

      money = Ecto.Changeset.get_change(changeset, :price)
      assert money.currency == :JPY
    end

    test "validate_money/3 rejects mismatched currency" do
      # Stash the parsed Money directly — the schemaless cast path
      # would otherwise need ecto_sql for the composite type.
      changeset = Ecto.Changeset.change({%{price: Money.new(:USD, "10")}, %{price: :map}})
      changeset = Money.Input.Changeset.validate_money(changeset, :price, currency: :EUR)
      refute changeset.valid?
      assert {"must be EUR", _} = changeset.errors[:price]
    end
  end

  # ── helpers ─────────────────────────────────────────────────

  defp money_assigns(field, overrides) do
    form = Phoenix.HTML.FormData.to_form(%{Atom.to_string(field) => "1234.56"}, as: :demo)

    overrides = Enum.into(overrides, %{})
    Map.merge(%{form: form, field: field, locale: "en"}, overrides)
  end
end
