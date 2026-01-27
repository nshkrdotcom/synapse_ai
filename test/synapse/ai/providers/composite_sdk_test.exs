defmodule Synapse.AI.Providers.CompositeSDKTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Providers.CompositeSDK

  describe "prepare_body/3" do
    test "returns params unchanged" do
      params = %{prompt: "test"}
      assert CompositeSDK.prepare_body(params, [], []) == params
    end
  end

  describe "supported_features/0" do
    test "returns union of all provider features" do
      features = CompositeSDK.supported_features()
      assert is_list(features)
      assert :streaming in features
      assert :embeddings in features
      assert :code_generation in features
      assert :system_instruction in features
    end
  end

  describe "default_config/0" do
    test "returns default fallback order" do
      config = CompositeSDK.default_config()
      assert is_list(config)
      assert config[:fallback_order] == [:gemini, :claude, :codex]
    end
  end

  describe "parse_response/2" do
    test "returns response unchanged" do
      response = %{content: "test"}
      assert CompositeSDK.parse_response(response, %{}) == {:ok, response}
    end
  end

  describe "translate_error/2" do
    test "returns error unchanged" do
      error = Jido.Error.execution_error("test")
      assert CompositeSDK.translate_error(error, %{}) == error
    end
  end

  describe "adapter_map/0" do
    test "returns map of adapter atoms to portfolio_index modules" do
      map = CompositeSDK.adapter_map()
      assert is_map(map)
      assert map[:gemini] == PortfolioIndex.Adapters.LLM.Gemini
      assert map[:claude] == PortfolioIndex.Adapters.LLM.Anthropic
      assert map[:codex] == PortfolioIndex.Adapters.LLM.Codex
      assert map[:openai] == PortfolioIndex.Adapters.LLM.OpenAI
      assert map[:ollama] == PortfolioIndex.Adapters.LLM.Ollama
    end
  end

  describe "resolve_adapter/1" do
    test "resolves known adapter atoms" do
      assert CompositeSDK.resolve_adapter(:gemini) == PortfolioIndex.Adapters.LLM.Gemini
      assert CompositeSDK.resolve_adapter(:claude) == PortfolioIndex.Adapters.LLM.Anthropic
      assert CompositeSDK.resolve_adapter(:codex) == PortfolioIndex.Adapters.LLM.Codex
      assert CompositeSDK.resolve_adapter(:openai) == PortfolioIndex.Adapters.LLM.OpenAI
      assert CompositeSDK.resolve_adapter(:ollama) == PortfolioIndex.Adapters.LLM.Ollama
    end

    test "returns nil for unknown adapter" do
      assert CompositeSDK.resolve_adapter(:unknown) == nil
    end
  end
end
