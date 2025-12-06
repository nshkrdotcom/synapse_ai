defmodule Synapse.AI do
  @moduledoc """
  Synapse integration for altar_ai.

  Provides SDK-backed LLM providers and workflow actions
  that use altar_ai's unified adapter layer instead of raw HTTP.

  ## Benefits over HTTP-based providers

  - Full SDK features (caching, streaming, auth management)
  - Automatic fallback chains via Composite adapter
  - Unified error handling
  - Shared telemetry with FlowStone (if both used)
  - Type-safe adapter interfaces

  ## Installation

      {:synapse_ai, path: "../synapse_ai"}

  ## Configuration

  Configure SDK-backed providers in your Synapse ReqLLM profiles:

      config :synapse, Synapse.ReqLLM,
        profiles: %{
          gemini_sdk: [
            provider_module: Synapse.AI.Providers.GeminiSDK,
            model: "gemini-pro"
          ],
          claude_sdk: [
            provider_module: Synapse.AI.Providers.ClaudeSDK,
            model: "claude-opus-4-5-20251101"
          ],
          codex_sdk: [
            provider_module: Synapse.AI.Providers.CodexSDK,
            model: "gpt-4o"
          ],
          composite: [
            provider_module: Synapse.AI.Providers.CompositeSDK,
            fallback_order: [:gemini, :claude, :codex]
          ]
        }

  ## Usage in Workflows

      alias Synapse.Workflow.{Spec, Step}

      Spec.new(
        name: :ai_workflow,
        steps: [
          Step.new(
            id: :classify,
            action: Synapse.AI.Actions.Classify,
            params: %{
              text: "This is amazing!",
              labels: ["positive", "negative", "neutral"]
            }
          ),
          Step.new(
            id: :generate,
            action: Synapse.AI.Actions.Generate,
            params: %{
              prompt: "Summarize the sentiment analysis",
              adapter: :gemini
            }
          )
        ]
      )

  ## Signal Handlers

      # Register AI-powered signal processing
      Synapse.SignalRouter.register_handler(
        :incoming_messages,
        &Synapse.AI.SignalHandlers.classify_and_route/2,
        labels: ["urgent", "normal", "spam"],
        text_path: [:data, :message]
      )

  ## Telemetry

  Enable telemetry forwarding from altar_ai to synapse.ai namespace:

      # In your application.ex
      def start(_type, _args) do
        Synapse.AI.setup_telemetry()
        # ...
      end
  """

  alias Synapse.AI.Providers

  @doc """
  Setup telemetry bridge to forward altar_ai events to synapse.ai namespace.
  """
  def setup_telemetry do
    Synapse.AI.Telemetry.attach()
  end

  @doc """
  Get list of available SDK-backed providers based on configured adapters.

  Returns a list of provider modules that can be used in ReqLLM profiles.

  ## Examples

      iex> Synapse.AI.available_providers()
      [Synapse.AI.Providers.CompositeSDK, Synapse.AI.Providers.GeminiSDK]
  """
  def available_providers do
    providers = []

    providers =
      if Code.ensure_loaded?(Altar.AI.Adapters.Gemini) and
           function_exported?(Altar.AI.Adapters.Gemini, :available?, 0) and
           Altar.AI.Adapters.Gemini.available?() do
        [Providers.GeminiSDK | providers]
      else
        providers
      end

    providers =
      if Code.ensure_loaded?(Altar.AI.Adapters.Claude) and
           function_exported?(Altar.AI.Adapters.Claude, :available?, 0) and
           Altar.AI.Adapters.Claude.available?() do
        [Providers.ClaudeSDK | providers]
      else
        providers
      end

    providers =
      if Code.ensure_loaded?(Altar.AI.Adapters.Codex) and
           function_exported?(Altar.AI.Adapters.Codex, :available?, 0) and
           Altar.AI.Adapters.Codex.available?() do
        [Providers.CodexSDK | providers]
      else
        providers
      end

    # Composite always available
    [Providers.CompositeSDK | providers]
  end

  @doc """
  Get version information.

  ## Examples

      iex> Synapse.AI.version()
      "0.1.0"
  """
  def version do
    Application.spec(:synapse_ai, :vsn) |> to_string()
  end

  @doc """
  Check if synapse_ai is properly configured and ready to use.

  ## Examples

      iex> Synapse.AI.ready?()
      true
  """
  def ready? do
    Code.ensure_loaded?(Altar.AI) and
      Code.ensure_loaded?(Synapse.LLMProvider) and
      Code.ensure_loaded?(Jido.Action)
  end
end
