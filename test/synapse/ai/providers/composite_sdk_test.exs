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
      error = %Jido.Error{type: :test, message: "test"}
      assert CompositeSDK.translate_error(error, %{}) == error
    end
  end
end
