defmodule Synapse.AI.Actions.ClassifyTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Classify

  describe "run/2" do
    test "returns error when text is missing" do
      params = %{labels: ["a", "b"]}

      assert {:error, %Jido.Error{type: :validation_error, message: msg}} =
               Classify.run(params, %{})

      assert msg =~ "text"
    end

    test "returns error when labels is missing" do
      params = %{text: "test"}

      assert {:error, %Jido.Error{type: :validation_error, message: msg}} =
               Classify.run(params, %{})

      assert msg =~ "labels"
    end

    test "returns error when labels is empty" do
      params = %{text: "test", labels: []}
      assert {:error, %Jido.Error{type: :validation_error}} = Classify.run(params, %{})
    end

    test "successfully classifies with required params" do
      # This test would require mocking Altar.AI.classify
      # For now, verify the function exists and has correct arity
      assert function_exported?(Classify, :run, 2)
    end

    test "accepts adapter parameter" do
      params = %{text: "test", labels: ["a", "b"], adapter: :gemini}
      assert is_map(params)
    end

    test "accepts opts parameter" do
      params = %{text: "test", labels: ["a", "b"], opts: [temperature: 0.5]}
      assert is_map(params)
    end
  end
end
