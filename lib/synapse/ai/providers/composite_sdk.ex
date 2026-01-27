defmodule Synapse.AI.Providers.CompositeSDK do
  @moduledoc """
  Synapse LLMProvider with automatic fallback across all available portfolio adapters.

  Tries providers in configured fallback order until one succeeds.
  Uses portfolio_index LLM adapters for the actual calls.

  ## Configuration

      config :synapse, Synapse.ReqLLM,
        profiles: %{
          composite: [
            provider_module: Synapse.AI.Providers.CompositeSDK,
            # Optional: specify fallback order
            fallback_order: [:gemini, :claude, :codex, :openai, :ollama]
          ]
        }

  ## Automatic Fallback

  The composite provider will try providers in order until one succeeds:
  1. Gemini (if configured)
  2. Claude (if configured)
  3. Codex (if configured)
  4. OpenAI (if configured)
  5. Ollama (if configured)

  If all providers fail, it returns the last error encountered.
  """

  @behaviour Synapse.LLMProvider

  require Logger

  @adapter_map %{
    gemini: PortfolioIndex.Adapters.LLM.Gemini,
    claude: PortfolioIndex.Adapters.LLM.Anthropic,
    codex: PortfolioIndex.Adapters.LLM.Codex,
    openai: PortfolioIndex.Adapters.LLM.OpenAI,
    ollama: PortfolioIndex.Adapters.LLM.Ollama
  }

  @impl true
  def prepare_body(params, _profile_config, _global_config) do
    params
  end

  def chat_completion(params, profile_config, _global_config) do
    fallback_order = Keyword.get(profile_config, :fallback_order, [:gemini, :claude, :codex])
    messages = build_messages(params)
    opts = Keyword.drop(profile_config, [:fallback_order])

    try_adapters(fallback_order, messages, opts, nil)
  end

  @impl true
  def parse_response(response, _metadata) do
    {:ok, response}
  end

  @impl true
  def translate_error(error, _metadata) do
    error
  end

  @impl true
  def supported_features do
    [:streaming, :embeddings, :code_generation, :system_instruction]
  end

  @impl true
  def default_config do
    [fallback_order: [:gemini, :claude, :codex]]
  end

  @doc """
  Returns the map of adapter atoms to portfolio_index adapter modules.
  """
  def adapter_map, do: @adapter_map

  @doc """
  Resolves an adapter atom to its portfolio_index module.
  """
  def resolve_adapter(atom) when is_atom(atom) do
    Map.get(@adapter_map, atom)
  end

  defp try_adapters([], _messages, _opts, last_error) do
    error = last_error || Jido.Error.execution_error("All providers failed")
    {:error, error}
  end

  defp try_adapters([provider | rest], messages, opts, _last_error) do
    case Map.get(@adapter_map, provider) do
      nil ->
        Logger.warning("Unknown provider #{inspect(provider)} in fallback chain, skipping")
        try_adapters(rest, messages, opts, nil)

      adapter ->
        case adapter.complete(messages, opts) do
          {:ok, response} ->
            {:ok, to_synapse_response(response, provider)}

          {:error, error} ->
            Logger.debug("Provider #{inspect(provider)} failed: #{inspect(error)}, trying next")
            try_adapters(rest, messages, opts, to_synapse_error(error))
        end
    end
  end

  defp build_messages(params) do
    prompt = extract_prompt(params)

    case params do
      %{messages: messages} when is_list(messages) ->
        messages

      _ ->
        [%{role: :user, content: prompt}]
    end
  end

  defp extract_prompt(params) do
    case params do
      %{prompt: prompt} when is_binary(prompt) -> prompt
      %{messages: [%{content: content} | _]} when is_binary(content) -> content
      %{"prompt" => prompt} when is_binary(prompt) -> prompt
      %{"messages" => [%{"content" => content} | _]} when is_binary(content) -> content
      _ -> ""
    end
  end

  defp to_synapse_response(response, provider) when is_map(response) do
    %{
      content: Map.get(response, :content, ""),
      metadata: %{
        provider_id: to_string(provider),
        model: Map.get(response, :model, "unknown"),
        total_tokens:
          get_in_usage(response, :input_tokens, 0) + get_in_usage(response, :output_tokens, 0),
        prompt_tokens: get_in_usage(response, :input_tokens, 0),
        completion_tokens: get_in_usage(response, :output_tokens, 0),
        finish_reason: to_string(Map.get(response, :finish_reason, :stop))
      }
    }
  end

  defp get_in_usage(response, key, default) do
    case Map.get(response, :usage) do
      %{} = usage -> Map.get(usage, key, default)
      _ -> default
    end
  end

  defp to_synapse_error(error) do
    case error do
      %{__exception__: true} = e -> e
      reason -> Jido.Error.execution_error(inspect(reason))
    end
  end
end
