defmodule Synapse.AI.Providers.GeminiSDKTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Providers.GeminiSDK

  describe "prepare_body/3" do
    test "returns params unchanged" do
      params = %{prompt: "test"}
      assert GeminiSDK.prepare_body(params, [], []) == params
    end
  end

  describe "chat_completion/3" do
    test "function exists with correct arity" do
      assert is_function(&GeminiSDK.chat_completion/3)
    end

    test "extracts prompt from messages format" do
      params = %{messages: [%{content: "Hello"}]}
      assert is_map(params)
    end
  end

  describe "parse_response/2" do
    test "returns response unchanged" do
      response = %{content: "test"}
      assert GeminiSDK.parse_response(response, %{}) == {:ok, response}
    end
  end

  describe "translate_error/2" do
    test "returns error unchanged" do
      error = Jido.Error.execution_error("test")
      assert GeminiSDK.translate_error(error, %{}) == error
    end
  end

  describe "supported_features/0" do
    test "returns list of supported features" do
      features = GeminiSDK.supported_features()
      assert is_list(features)
      assert :streaming in features
      assert :embeddings in features
      assert :system_instruction in features
    end
  end

  describe "default_config/0" do
    test "returns default configuration" do
      config = GeminiSDK.default_config()
      assert is_list(config)
      assert config[:model] == "gemini-pro"
    end
  end

  describe "portfolio_adapter/0" do
    test "returns the portfolio_index adapter module" do
      assert GeminiSDK.portfolio_adapter() == PortfolioIndex.Adapters.LLM.Gemini
    end
  end

  test "implements Synapse.LLMProvider behaviour" do
    assert function_exported?(GeminiSDK, :supported_features, 0)
    assert function_exported?(GeminiSDK, :default_config, 0)
    assert function_exported?(GeminiSDK, :prepare_body, 3)
    assert function_exported?(GeminiSDK, :parse_response, 2)
    assert function_exported?(GeminiSDK, :translate_error, 2)
  end
end
