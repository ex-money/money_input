defmodule Money.Input.AdversarialRenderTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Exercises every public component with adversarial attr
  values. Asserts no exception is raised — a render-path
  crash 500s the consumer's page on input they can't
  necessarily validate ahead of time.
  """

  alias Money.Input.{Components, Cast, Validator}

  @bad_atoms [nil, :"", :unknown, :__bad__]
  @bad_strings [nil, "", "garbage", "🙂", String.duplicate("a", 1000)]
  @bad_currencies [nil, :"", :ZZZ, :__bad__, "", "ZZZ", "garbage", 42]
  @bad_amounts [nil, "", "garbage", :"", %{}, [], "1.2.3.4", "$"]

  describe "money_input/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:money_input, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :default_currency" do
      for currency <- @bad_currencies do
        assert_no_raise(fn -> render(:money_input, default_currency: currency) end,
          context: "default_currency=#{inspect(currency)}"
        )
      end
    end

    test "renders for every adversarial submitted amount" do
      for amount <- @bad_amounts do
        form =
          Phoenix.HTML.FormData.to_form(
            %{"money_input" => %{"amount" => amount, "currency" => "USD"}},
            as: :event
          )

        assert_no_raise(fn -> render(:money_input, form: form) end,
          context: "amount=#{inspect(amount)}"
        )
      end
    end

    test "renders for every adversarial submitted currency" do
      for currency <- @bad_currencies do
        form =
          Phoenix.HTML.FormData.to_form(
            %{"money_input" => %{"amount" => "10.00", "currency" => to_string_safe(currency)}},
            as: :event
          )

        assert_no_raise(fn -> render(:money_input, form: form) end,
          context: "submitted currency=#{inspect(currency)}"
        )
      end
    end

    test "renders for every adversarial :min / :max" do
      for bound <- [nil, "", "garbage", :"", %{}, [], 1, 1.5, Decimal.new(0)] do
        assert_no_raise(fn -> render(:money_input, min: bound) end,
          context: "min=#{inspect(bound)}"
        )

        assert_no_raise(fn -> render(:money_input, max: bound) end,
          context: "max=#{inspect(bound)}"
        )
      end
    end

    test "picker on with empty currency must not 500" do
      # Specific regression — 0.2.0 crashed when the picker
      # was on and the form submitted an empty currency.
      form =
        Phoenix.HTML.FormData.to_form(
          %{"money_input" => %{"amount" => "", "currency" => ""}},
          as: :event
        )

      assert_no_raise(
        fn -> render(:money_input, form: form, currency_picker: true, default_currency: nil) end,
        context: "picker on + empty currency + nil default"
      )
    end
  end

  describe "currency_picker/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(
          fn ->
            render(:currency_picker, locale: locale, current: :USD)
          end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :current" do
      for currency <- @bad_currencies do
        assert_no_raise(fn -> render(:currency_picker, current: currency) end,
          context: "current=#{inspect(currency)}"
        )
      end
    end

    test "renders for every adversarial :preferred" do
      for preferred <- [nil, [], [:""], [:ZZZ], [nil], ["garbage"], 42] do
        assert_no_raise(fn -> render(:currency_picker, preferred: preferred) end,
          context: "preferred=#{inspect(preferred)}"
        )
      end
    end
  end

  describe "Cast.cast/2" do
    test "never raises on adversarial input" do
      for amount <- @bad_amounts,
          currency <- @bad_currencies,
          locale <- [:en, nil, "", :"", "garbage"] do
        value = %{"amount" => to_string_safe(amount), "currency" => to_string_safe(currency)}

        try do
          _ = Cast.cast(value, locale: locale, currency: currency)
        rescue
          e ->
            flunk("""
            Cast.cast raised for value=#{inspect(value)} locale=#{inspect(locale)} currency=#{inspect(currency)}:
              #{Exception.format(:error, e, [])}
            """)
        end
      end
    end
  end

  describe "Validator.validate_money/2" do
    test "never raises on adversarial input" do
      bogus = [nil, "garbage", :"", %{}, [], 42, Decimal.new("1.5")]

      for value <- bogus do
        try do
          _ = Validator.validate_money(value)
        rescue
          e ->
            flunk("""
            Validator.validate_money raised for value=#{inspect(value)}:
              #{Exception.format(:error, e, [])}
            """)
        end
      end
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  defp render(component, overrides) do
    _ = :__bad__

    base_form =
      Phoenix.HTML.FormData.to_form(
        %{"money_input" => %{"amount" => "", "currency" => "USD"}, "currency" => "USD"},
        as: :event
      )

    base_assigns = %{
      __changed__: nil,
      form: base_form,
      field: :money_input,
      currency_field: :currency,
      value: nil,
      locale: :en,
      default_currency: :USD,
      min: nil,
      max: nil,
      align: :right,
      placeholder: nil,
      symbol_position: :auto,
      symbol_kind: :symbol,
      js: true,
      class: nil,
      input_class: nil,
      symbol_class: nil,
      currency_picker: false,
      allowed_currencies: nil,
      preferred_currencies: [],
      rest: %{}
    }

    picker_assigns = %{
      __changed__: nil,
      form: nil,
      field: nil,
      name: "currency",
      input_id: nil,
      current: :USD,
      locale: :en,
      allowed: nil,
      preferred: [],
      class: nil,
      button_class: nil,
      symbol: nil,
      symbol_class: nil,
      currency_picker: true,
      currency: :USD,
      allowed_currencies: nil,
      preferred_currencies: [],
      currency_name: nil,
      currency_id: nil,
      id: "test-picker",
      variant: :auto,
      recents_limit: 8
    }

    assigns =
      case component do
        :money_input -> Map.merge(base_assigns, Map.new(overrides))
        :currency_picker -> Map.merge(picker_assigns, Map.new(overrides))
      end

    rendered =
      case component do
        :money_input -> Components.money_input(assigns)
        :currency_picker -> Components.currency_picker(assigns)
      end

    _ = rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
    :ok
  end

  defp assert_no_raise(fun, context: ctx) do
    try do
      fun.()
    rescue
      e ->
        flunk("""
        Component raised an exception under #{ctx}:

          #{Exception.format(:error, e, [])}
        """)
    end
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(:""), do: ""

  defp to_string_safe(value) do
    try do
      to_string(value)
    rescue
      _ -> inspect(value)
    end
  end
end
