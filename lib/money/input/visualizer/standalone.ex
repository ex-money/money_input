# `Money.Input.Visualizer.Standalone` runs the visualizer as a
# self-contained Bandit web server. It is only defined when
# `:bandit` is available (which transitively pulls in `:plug`),
# so consumer apps that don't need a standalone dev server
# don't get compiler warnings about missing modules. When
# `:bandit` isn't installed, this module simply doesn't exist
# and any call to it raises the standard
# `UndefinedFunctionError`.
if Code.ensure_loaded?(Bandit) do
  defmodule Money.Input.Visualizer.Standalone do
    @moduledoc """
    A tiny helper that runs `Money.Input.Visualizer` as a
    standalone web server for local development.

    Requires `:bandit` in your project's deps. This module is
    only compiled when `:bandit` is present — without it,
    `Money.Input.Visualizer.Standalone` doesn't exist and
    calling its functions raises `UndefinedFunctionError`.

        Money.Input.Visualizer.Standalone.start(port: 4002)
        # Visit http://localhost:4002

    To stop the server, call
    `Money.Input.Visualizer.Standalone.stop/1` with the PID
    returned from `start/1`.

    ## Enable flag

    For safety, this helper refuses to start unless the
    visualizer has been enabled — either via config:

        config :money_input, visualizer: true

    …or by passing `enabled: true` to `start/1` explicitly. The
    intent is to make accidental deployment of a developer tool
    to production loud rather than silent. Mounting
    `Money.Input.Visualizer` directly under `forward/2` in a host
    Phoenix router bypasses this — that path is up to the host
    to gate.

    """

    @doc """
    Starts the visualizer on the given port.

    ### Options

    * `:port` — TCP port to listen on. Default `4002`.

    * `:ip` — IP address to bind to. Default `:loopback` (only
      accessible from localhost). Pass `:any` to bind on all
      interfaces.

    * `:enabled` — when `true`, override the
      `:money_input, :visualizer` config check. Default `false`.

    ### Returns

    * `{:ok, pid}` on success.

    * `{:error, :visualizer_disabled}` when the visualizer has
      not been enabled. See the module doc.

    * `{:error, reason}` on other failures (e.g. port-in-use).

    ### Examples

        iex> Application.put_env(:money_input, :visualizer, true)
        iex> {:ok, pid} = Money.Input.Visualizer.Standalone.start(port: 0)
        iex> :ok = Money.Input.Visualizer.Standalone.stop(pid)

    """
    @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
    def start(options \\ []) do
      if enabled?(options) do
        port = Keyword.get(options, :port, 4002)
        ip = Keyword.get(options, :ip, :loopback)

        Bandit.start_link(
          plug: Money.Input.Visualizer,
          port: port,
          ip: ip_tuple(ip)
        )
      else
        {:error, :visualizer_disabled}
      end
    end

    @doc """
    Returns a child spec suitable for embedding under a
    supervision tree.

    Honours the same enable-flag rules as `start/1`. When the
    flag is off, the child spec is a no-op task that exits
    `:normal`, so a supervisor with a permanent restart strategy
    won't keep retrying.

    ### Options

    See `start/1`.

    ### Returns

    * A child specification map.

    """
    @spec child_spec(keyword()) :: Supervisor.child_spec()
    def child_spec(options \\ []) do
      if enabled?(options) do
        port = Keyword.get(options, :port, 4002)
        ip = Keyword.get(options, :ip, :loopback)

        %{
          id: __MODULE__,
          start:
            {Bandit, :start_link, [[plug: Money.Input.Visualizer, port: port, ip: ip_tuple(ip)]]},
          type: :supervisor
        }
      else
        %{
          id: __MODULE__,
          start: {Task, :start_link, [fn -> :ok end]},
          restart: :temporary,
          type: :worker
        }
      end
    end

    @doc """
    Stops a standalone server started by `start/1`.

    ### Arguments

    * `pid` — the process identifier returned by `start/1`.

    ### Returns

    * `:ok`.

    """
    @spec stop(pid()) :: :ok
    def stop(pid) when is_pid(pid) do
      _ = Supervisor.stop(pid)
      :ok
    end

    @doc """
    Returns `true` when the visualizer is enabled via config or
    via the `:enabled` option.
    """
    @spec enabled?(keyword()) :: boolean()
    def enabled?(options \\ []) do
      cond do
        Keyword.get(options, :enabled) == true -> true
        Application.get_env(:money_input, :visualizer) == true -> true
        true -> false
      end
    end

    # ---- helpers ------------------------------------------------------------

    defp ip_tuple(:loopback), do: {127, 0, 0, 1}
    defp ip_tuple(:any), do: {0, 0, 0, 0}
    defp ip_tuple({_, _, _, _} = tuple), do: tuple
  end
end
