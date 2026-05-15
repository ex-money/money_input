defmodule Money.Input.VisualizerDisabledError do
  @moduledoc """
  Raised by `Money.Input.Visualizer.Standalone.start/1` when the
  visualizer hasn't been opted into.

  The visualizer is a development tool. To keep it from
  accidentally shipping to production, the standalone helper
  refuses to start unless either:

  * `config :money_input, visualizer: true` is set in the host
    app's config, or

  * `start/1` is called with `enabled: true` explicitly.

  """

  defexception []

  @type t :: %__MODULE__{}

  @impl true
  def exception(_bindings), do: %__MODULE__{}

  @impl true
  def message(%__MODULE__{}) do
    "Money.Input.Visualizer is disabled. Set `config :money_input, " <>
      "visualizer: true` or pass `enabled: true` to start/1."
  end
end
