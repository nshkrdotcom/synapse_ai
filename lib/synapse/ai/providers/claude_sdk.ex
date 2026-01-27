defmodule Synapse.AI.Providers.ClaudeSDK do
  @moduledoc """
  Synapse LLMProvider backed by Anthropic Claude via portfolio_index.

  Delegates to `PortfolioIndex.Adapters.LLM.Anthropic` for the actual LLM calls
  while implementing the `Synapse.LLMProvider` behaviour contract.

  ## Configuration

      config :synapse, Synapse.ReqLLM,
        profiles: %{
          claude_sdk: [
            provider_module: Synapse.AI.Providers.ClaudeSDK,
            model: "claude-opus-4-5-20251101"
          ]
        }

  ## Examples

      iex> params = %{prompt: "Explain quantum computing"}
      iex> profile_config = [model: "claude-opus-4-5-20251101"]
      iex> {:ok, response} = Synapse.AI.Providers.ClaudeSDK.chat_completion(params, profile_config, [])
      iex> is_binary(response.content)
      true
  """

  @behaviour Synapse.LLMProvider

  require Logger

  @adapter PortfolioIndex.Adapters.LLM.Anthropic

  @impl true
  def prepare_body(params, _profile_config, _global_config) do
    params
  end

  def chat_completion(params, profile_config, _global_config) do
    messages = build_messages(params)
    opts = Keyword.merge(default_config(), profile_config)

    case @adapter.complete(messages, opts) do
      {:ok, response} -> {:ok, to_synapse_response(response)}
      {:error, error} -> {:error, to_synapse_error(error)}
    end
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
    [:streaming, :extended_thinking, :prompt_caching, :system_instruction]
  end

  @impl true
  def default_config do
    [model: "claude-opus-4-5-20251101"]
  end

  @doc """
  Returns the underlying portfolio_index adapter module.
  """
  def portfolio_adapter, do: @adapter

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

  defp to_synapse_response(response) when is_map(response) do
    %{
      content: Map.get(response, :content, ""),
      metadata: %{
        provider_id: "anthropic",
        model: Map.get(response, :model, "claude-opus-4-5-20251101"),
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
