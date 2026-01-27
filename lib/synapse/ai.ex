defmodule Synapse.AI do
  @moduledoc """
  Synapse integration for portfolio_core/portfolio_index.

  Provides SDK-backed LLM providers and workflow actions
  that use portfolio_index's adapter layer instead of raw HTTP.

  ## Benefits over HTTP-based providers

  - Full SDK features (caching, streaming, auth management)
  - Automatic fallback chains via Composite adapter
  - Unified error handling
  - Rate limiting via portfolio_index
  - 6 provider adapters (Gemini, Claude, Codex, OpenAI, Ollama, VLLM)
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
            fallback_order: [:gemini, :claude, :codex, :openai, :ollama]
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

  Enable telemetry forwarding from portfolio_index to synapse.ai namespace:

      # In your application.ex
      def start(_type, _args) do
        Synapse.AI.setup_telemetry()
        # ...
      end
  """

  alias Synapse.AI.Providers
  alias Synapse.AI.Telemetry

  @doc """
  Setup telemetry bridge to forward portfolio_index events to synapse.ai namespace.
  """
  def setup_telemetry do
    Telemetry.attach()
  end

  @doc """
  Get list of available SDK-backed providers based on configured adapters.

  Returns a list of provider modules that can be used in ReqLLM profiles.

  ## Examples

      iex> Synapse.AI.available_providers()
      [Synapse.AI.Providers.CompositeSDK, Synapse.AI.Providers.GeminiSDK, ...]
  """
  def available_providers do
    providers = []

    providers =
      if adapter_loaded?(PortfolioIndex.Adapters.LLM.Gemini) do
        [Providers.GeminiSDK | providers]
      else
        providers
      end

    providers =
      if adapter_loaded?(PortfolioIndex.Adapters.LLM.Anthropic) do
        [Providers.ClaudeSDK | providers]
      else
        providers
      end

    providers =
      if adapter_loaded?(PortfolioIndex.Adapters.LLM.Codex) do
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
    Code.ensure_loaded?(PortfolioCore.Ports.LLM) and
      Code.ensure_loaded?(PortfolioIndex.Adapters.LLM.Gemini) and
      Code.ensure_loaded?(Synapse.LLMProvider) and
      Code.ensure_loaded?(Jido.Action)
  end

  defp adapter_loaded?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :complete, 2)
  end
end
