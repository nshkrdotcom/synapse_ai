defmodule Synapse.AI.Telemetry do
  @moduledoc """
  Bridges portfolio_index telemetry to Synapse's telemetry namespace.

  Automatically forwards all portfolio_index telemetry events to the synapse.ai namespace,
  allowing unified monitoring and metrics collection across the Synapse ecosystem.

  ## Usage

      # In your application startup
      Synapse.AI.Telemetry.attach()

  ## Events Forwarded

  All events from the `:portfolio_index` namespace are forwarded to `:synapse, :ai`:

  - `[:portfolio_index, :llm, :complete, :start]` -> `[:synapse, :ai, :generate, :start]`
  - `[:portfolio_index, :llm, :complete, :stop]` -> `[:synapse, :ai, :generate, :stop]`
  - `[:portfolio_index, :llm, :complete, :exception]` -> `[:synapse, :ai, :generate, :exception]`
  - `[:portfolio_index, :embedder, :embed]` -> `[:synapse, :ai, :embed, :stop]`
  - `[:portfolio_index, :embedder, :embed_batch]` -> `[:synapse, :ai, :batch_embed, :stop]`

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
    [:portfolio_index, :llm, :complete, :start],
    [:portfolio_index, :llm, :complete, :stop],
    [:portfolio_index, :llm, :complete, :exception],
    [:portfolio_index, :llm, :stream, :start],
    [:portfolio_index, :llm, :stream, :stop],
    [:portfolio_index, :llm, :stream, :exception],
    [:portfolio_index, :embedder, :embed],
    [:portfolio_index, :embedder, :embed_batch]
  ]

  @event_mapping %{
    [:portfolio_index, :llm, :complete, :start] => [:synapse, :ai, :generate, :start],
    [:portfolio_index, :llm, :complete, :stop] => [:synapse, :ai, :generate, :stop],
    [:portfolio_index, :llm, :complete, :exception] => [:synapse, :ai, :generate, :exception],
    [:portfolio_index, :llm, :stream, :start] => [:synapse, :ai, :stream, :start],
    [:portfolio_index, :llm, :stream, :stop] => [:synapse, :ai, :stream, :stop],
    [:portfolio_index, :llm, :stream, :exception] => [:synapse, :ai, :stream, :exception],
    [:portfolio_index, :embedder, :embed] => [:synapse, :ai, :embed, :stop],
    [:portfolio_index, :embedder, :embed_batch] => [:synapse, :ai, :batch_embed, :stop]
  }

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
  def handle_event(event, measurements, metadata, _config) do
    synapse_evt = synapse_event(event)

    enhanced_metadata =
      Map.merge(metadata, %{
        source: :synapse_ai,
        forwarded_from: event
      })

    :telemetry.execute(synapse_evt, measurements, enhanced_metadata)
  end

  @doc """
  Returns the list of events that are being forwarded.
  """
  def forwarded_events do
    @events
  end

  @doc """
  Returns the corresponding Synapse event name for a portfolio_index event.

  ## Examples

      iex> Synapse.AI.Telemetry.synapse_event([:portfolio_index, :llm, :complete, :stop])
      [:synapse, :ai, :generate, :stop]
  """
  def synapse_event(event) do
    case Map.get(@event_mapping, event) do
      nil ->
        # Fallback: replace :portfolio_index prefix with :synapse, :ai
        case event do
          [:portfolio_index | rest] -> [:synapse, :ai | rest]
          other -> other
        end

      mapped ->
        mapped
    end
  end
end
