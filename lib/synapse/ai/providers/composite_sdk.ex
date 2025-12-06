defmodule Synapse.AI.Providers.CompositeSDK do
  @moduledoc """
  Synapse LLMProvider with automatic fallback across all available SDKs.

  Uses Altar.AI.Adapters.Composite under the hood for cascading provider support.
  This provider automatically falls back to the next available provider if one fails.

  ## Configuration

      config :synapse, Synapse.ReqLLM,
        profiles: %{
          composite: [
            provider_module: Synapse.AI.Providers.CompositeSDK,
            # Optional: specify fallback order
            fallback_order: [:gemini, :claude, :codex]
          ]
        }

  ## Examples

      iex> params = %{prompt: "Hello, world!"}
      iex> profile_config = []
      iex> {:ok, response} = Synapse.AI.Providers.CompositeSDK.chat_completion(params, profile_config, [])
      iex> is_binary(response.content)
      true

  ## Automatic Fallback

  The composite provider will try providers in order until one succeeds:
  1. Gemini (if configured)
  2. Claude (if configured)
  3. Codex (if configured)

  If all providers fail, it returns the last error encountered.
  """

  @behaviour Synapse.LLMProvider

  require Logger

  @impl true
  def prepare_body(params, _profile_config, _global_config) do
    # Not needed for SDK - we process directly
    params
  end

  def chat_completion(params, profile_config, _global_config) do
    adapter = build_composite_adapter(profile_config)
    prompt = extract_prompt(params)

    case Altar.AI.generate(adapter, prompt, params) do
      {:ok, response} -> {:ok, to_synapse_response(response)}
      {:error, error} -> {:error, to_synapse_error(error)}
    end
  end

  @impl true
  def parse_response(response, _metadata) do
    # Response already normalized by altar_ai
    {:ok, response}
  end

  @impl true
  def translate_error(error, _metadata) do
    # Error already normalized by altar_ai
    error
  end

  @impl true
  def supported_features do
    # Union of all available provider features
    [:streaming, :embeddings, :code_generation, :system_instruction]
  end

  @impl true
  def default_config do
    [fallback_order: [:gemini, :claude, :codex]]
  end

  defp build_composite_adapter(profile_config) do
    fallback_order = Keyword.get(profile_config, :fallback_order, [:gemini, :claude, :codex])

    adapters =
      fallback_order
      |> Enum.map(&build_adapter/1)
      |> Enum.reject(&is_nil/1)

    case adapters do
      [] ->
        # If no adapters configured, use default
        Altar.AI.Adapters.Composite.default()

      adapters ->
        Altar.AI.Adapters.Composite.new(adapters)
    end
  end

  defp build_adapter(:gemini) do
    if Altar.AI.Adapters.Gemini.available?() do
      Altar.AI.Adapters.Gemini.new()
    end
  end

  defp build_adapter(:claude) do
    if Altar.AI.Adapters.Claude.available?() do
      Altar.AI.Adapters.Claude.new()
    end
  end

  defp build_adapter(:codex) do
    if Altar.AI.Adapters.Codex.available?() do
      Altar.AI.Adapters.Codex.new()
    end
  end

  defp build_adapter(_), do: nil

  defp extract_prompt(params) do
    case params do
      %{prompt: prompt} when is_binary(prompt) ->
        prompt

      %{messages: [%{content: content} | _]} when is_binary(content) ->
        content

      %{"prompt" => prompt} when is_binary(prompt) ->
        prompt

      %{"messages" => [%{"content" => content} | _]} when is_binary(content) ->
        content

      _ ->
        ""
    end
  end

  defp to_synapse_response(%Altar.AI.Response{} = response) do
    %{
      content: response.content,
      metadata: %{
        provider_id: to_string(response.provider),
        model: response.model,
        total_tokens: response.tokens.total,
        prompt_tokens: response.tokens.prompt,
        completion_tokens: response.tokens.completion,
        finish_reason: to_string(response.finish_reason)
      }
    }
  end

  defp to_synapse_error(%Altar.AI.Error{} = error) do
    %Jido.Error{
      type: error.type,
      message: error.message,
      details: error.details
    }
  end
end
