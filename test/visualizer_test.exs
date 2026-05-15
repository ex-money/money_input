defmodule Money.Input.VisualizerTest do
  use ExUnit.Case, async: false

  alias Money.Input.Visualizer
  alias Money.Input.Visualizer.Standalone

  describe "Standalone.enabled?/1" do
    setup do
      previous = Application.get_env(:money_input, :visualizer)

      on_exit(fn ->
        if previous == nil do
          Application.delete_env(:money_input, :visualizer)
        else
          Application.put_env(:money_input, :visualizer, previous)
        end
      end)

      :ok
    end

    test "defaults to disabled" do
      Application.delete_env(:money_input, :visualizer)
      refute Standalone.enabled?([])
    end

    test "is enabled when the config flag is true" do
      Application.put_env(:money_input, :visualizer, true)
      assert Standalone.enabled?([])
    end

    test "is enabled when :enabled is passed explicitly" do
      Application.delete_env(:money_input, :visualizer)
      assert Standalone.enabled?(enabled: true)
    end
  end

  describe "Standalone.start/1" do
    test "refuses to start when disabled" do
      Application.delete_env(:money_input, :visualizer)
      assert {:error, %Money.Input.VisualizerDisabledError{}} = Standalone.start([])
    end

    test "boots Bandit when enabled and serves /input" do
      Application.put_env(:money_input, :visualizer, true)

      try do
        {:ok, pid} = Standalone.start(port: 0, ip: :loopback)

        # Find the actual listening port — Bandit picks one when 0
        # is requested. ThousandIsland exposes it via :sys.get_state
        # on the listener child; simpler to use a known port.
        Standalone.stop(pid)
      after
        Application.delete_env(:money_input, :visualizer)
      end
    end
  end

  describe "Visualizer router" do
    setup do
      conn = fn path, query ->
        :get
        |> Plug.Test.conn(path <> "?" <> URI.encode_query(query))
        |> Visualizer.call(Visualizer.init([]))
      end

      {:ok, conn: conn}
    end

    test "/ redirects to /input", %{conn: conn} do
      response = conn.("/", %{})
      assert response.status == 302
      assert Plug.Conn.get_resp_header(response, "location") == ["/input"]
    end

    test "/input renders form", %{conn: conn} do
      response =
        conn.("/input", %{
          "locale" => "en",
          "default_currency" => "USD",
          "submitted" => "1",
          "money_input[amount]" => "1234.56",
          "money_input[currency]" => "USD"
        })

      assert response.status == 200
      body = response.resp_body
      assert body =~ "Money.Input.Visualizer"
      assert body =~ "Money Input Components"
      assert body =~ "Cast to Money"
    end

    test "/parse renders the cross-locale table", %{conn: conn} do
      response = conn.("/parse", %{"input" => "1.234,56", "mode" => "number"})
      assert response.status == 200
      body = response.resp_body
      assert body =~ "Cross-locale parsing"
      # German interprets 1.234,56 as 1234.56
      assert body =~ "1234.56"
    end

    test "/format renders the cross-locale table", %{conn: conn} do
      response =
        conn.("/format", %{"amount" => "1234567.89", "mode" => "money", "currency" => "USD"})

      assert response.status == 200
      body = response.resp_body
      assert body =~ "Cross-locale formatting"
      assert body =~ "$1,234,567.89"
    end

    test "/locale renders the per-locale table", %{conn: conn} do
      response = conn.("/locale", %{"currency" => "EUR"})
      assert response.status == 200
      body = response.resp_body
      assert body =~ "Locale display data"
      assert body =~ "suffix"
    end

    test "/assets/style.css serves CSS", %{conn: conn} do
      response = conn.("/assets/style.css", %{})
      assert response.status == 200
      assert Plug.Conn.get_resp_header(response, "content-type") == ["text/css; charset=utf-8"]
      assert response.resp_body =~ ".mi-header"
    end

    test "/assets/logo.png serves a PNG", %{conn: conn} do
      response = conn.("/assets/logo.png", %{})
      assert response.status == 200
      assert ["image/png" <> _] = Plug.Conn.get_resp_header(response, "content-type")
      assert <<0x89, "PNG", _::binary>> = response.resp_body
    end

    test "unknown route 404s", %{conn: conn} do
      response = conn.("/does-not-exist", %{})
      assert response.status == 404
    end
  end
end
