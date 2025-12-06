defmodule Synapse.AI.Telemetry do
  @moduledoc """
  Bridges altar_ai telemetry to Synapse's telemetry namespace.

  Automatically forwards all altar_ai telemetry events to the synapse.ai namespace,
  allowing unified monitoring and metrics collection across the Synapse ecosystem.

  ## Usage

      # In your application startup
      Synapse.AI.Telemetry.attach()

  ## Events Forwarded

  All events from the `:altar` namespace are forwarded to `:synapse, :ai`:

  - `[:altar, :ai, :generate, :start]` -> `[:synapse, :ai, :generate, :start]`
  - `[:altar, :ai, :generate, :stop]` -> `[:synapse, :ai, :generate, :stop]`
  - `[:altar, :ai, :generate, :exception]` -> `[:synapse, :ai, :generate, :exception]`
  - `[:altar, :ai, :embed, :start]` -> `[:synapse, :ai, :embed, :start]`
  - `[:altar, :ai, :embed, :stop]` -> `[:synapse, :ai, :embed, :stop]`
  - `[:altar, :ai, :classify, :start]` -> `[:synapse, :ai, :classify, :start]`
  - `[:altar, :ai, :classify, :stop]` -> `[:synapse, :ai, :classify, :stop]`

  ## Example: Consuming Events

      :telemetry.attach(
        "my-handler",
        [:synapse, :ai, :generate, :stop],
        fn event, measurements, metadata, _config ->
          IO.puts("Generated text in \#{measurements.duration}ms")
        end,
        nil
      )
  """

  require Logger

  @events [
    [:altar, :ai, :generate, :start],
    [:altar, :ai, :generate, :stop],
    [:altar, :ai, :generate, :exception],
    [:altar, :ai, :embed, :start],
    [:altar, :ai, :embed, :stop],
    [:altar, :ai, :embed, :exception],
    [:altar, :ai, :classify, :start],
    [:altar, :ai, :classify, :stop],
    [:altar, :ai, :classify, :exception],
    [:altar, :ai, :batch_embed, :start],
    [:altar, :ai, :batch_embed, :stop],
    [:altar, :ai, :batch_embed, :exception]
  ]

  @doc """
  Attaches the telemetry bridge.

  This should be called once during application startup.
  """
  def attach do
    :telemetry.attach_many(
      "synapse-ai-telemetry-bridge",
      @events,
      &handle_event/4,
      nil
    )

    Logger.debug("Synapse.AI telemetry bridge attached")
  end

  @doc """
  Detaches the telemetry bridge.
  """
  def detach do
    :telemetry.detach("synapse-ai-telemetry-bridge")
    Logger.debug("Synapse.AI telemetry bridge detached")
  end

  @doc false
  def handle_event([:altar, :ai | rest], measurements, metadata, _config) do
    # Forward to Synapse namespace
    synapse_event = [:synapse, :ai | rest]

    # Add synapse-specific metadata
    enhanced_metadata =
      Map.merge(metadata, %{
        source: :synapse_ai,
        forwarded_from: [:altar, :ai | rest]
      })

    :telemetry.execute(synapse_event, measurements, enhanced_metadata)
  end

  @doc """
  Returns the list of events that are being forwarded.
  """
  def forwarded_events do
    @events
  end

  @doc """
  Returns the corresponding Synapse event name for an Altar event.

  ## Examples

      iex> Synapse.AI.Telemetry.synapse_event([:altar, :ai, :generate, :stop])
      [:synapse, :ai, :generate, :stop]
  """
  def synapse_event([:altar, :ai | rest]) do
    [:synapse, :ai | rest]
  end

  def synapse_event(event) do
    event
  end
end
