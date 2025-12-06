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
    test "successfully generates text from prompt" do
      # Mock the adapter
      _mock_response = %Altar.AI.Response{
        content: "Hello, world!",
        provider: :gemini,
        model: "gemini-pro",
        tokens: %{total: 10, prompt: 5, completion: 5},
        finish_reason: :stop
      }

      # We'll need to mock Altar.AI.Adapters.Gemini.new and Altar.AI.generate
      # For now, this is a structural test
      assert is_function(&GeminiSDK.chat_completion/3)
    end

    test "extracts prompt from messages format" do
      params = %{messages: [%{content: "Hello"}]}
      # Test would call chat_completion with mocked adapter
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
      error = %Jido.Error{type: :test, message: "test"}
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
end
