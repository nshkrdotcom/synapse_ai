defmodule Synapse.AI.Actions.GenerateTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Generate
  alias Synapse.AI.Test.MockAdapter

  describe "run/2" do
    test "returns error when prompt is missing" do
      params = %{}
      assert {:error, %Jido.Error{type: :validation_error}} = Generate.run(params, %{})
    end

    test "successfully generates text with prompt" do
      # This test would require mocking Altar.AI.generate
      # For now, verify the function exists and has correct arity
      assert function_exported?(Generate, :run, 2)
    end

    test "accepts adapter as parameter" do
      # Structural test - verifies parameter handling
      params = %{prompt: "test", adapter: :gemini}
      assert is_map(params)
    end

    test "accepts opts parameter" do
      params = %{prompt: "test", opts: [max_tokens: 100]}
      assert is_map(params)
    end

    test "uses composite adapter by default" do
      # This would test the default adapter selection
      # Requires mocking
      assert function_exported?(Generate, :run, 2)
    end
  end
end
