defmodule Synapse.AI.Providers.CodexSDK do
  @moduledoc """
  Synapse LLMProvider backed by codex_sdk via altar_ai.

  Optimized for code generation tasks using OpenAI's Codex models.

  ## Configuration

      config :synapse, Synapse.ReqLLM,
        profiles: %{
          codex_sdk: [
            provider_module: Synapse.AI.Providers.CodexSDK,
            model: "gpt-4o"
          ]
        }

  ## Examples

      iex> params = %{prompt: "Write a function to sort an array"}
      iex> profile_config = [model: "gpt-4o"]
      iex> {:ok, response} = Synapse.AI.Providers.CodexSDK.chat_completion(params, profile_config, [])
      iex> is_binary(response.content)
      true
  """

  @behaviour Synapse.LLMProvider

  require Logger

  @impl true
  def prepare_body(params, _profile_config, _global_config) do
    # Not needed for SDK - we process directly
    params
  end

  def chat_completion(params, profile_config, _global_config) do
    adapter = Altar.AI.Adapters.Codex.new(profile_config)
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
    [:streaming, :code_generation, :function_calling]
  end

  @impl true
  def default_config do
    [model: "gpt-4o"]
  end

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
