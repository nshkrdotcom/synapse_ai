defmodule Synapse.AI.Actions.ClassifyTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Classify

  setup_all do
    Code.ensure_loaded?(Classify)
    :ok
  end

  describe "run/2" do
    test "returns error when text is missing" do
      params = %{labels: ["a", "b"]}

      assert {:error, %Jido.Error.ValidationError{message: msg}} =
               Classify.run(params, %{})

      assert msg =~ "text"
    end

    test "returns error when labels is missing" do
      params = %{text: "test"}

      assert {:error, %Jido.Error.ValidationError{message: msg}} =
               Classify.run(params, %{})

      assert msg =~ "labels"
    end

    test "returns error when labels is empty" do
      params = %{text: "test", labels: []}
      assert {:error, %Jido.Error.ValidationError{}} = Classify.run(params, %{})
    end

    test "successfully classifies with required params" do
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

  describe "resolve_adapter/1" do
    test "resolves adapter from atom" do
      assert Classify.resolve_adapter(:gemini) == PortfolioIndex.Adapters.LLM.Gemini
      assert Classify.resolve_adapter(:claude) == PortfolioIndex.Adapters.LLM.Anthropic
      assert Classify.resolve_adapter(:codex) == PortfolioIndex.Adapters.LLM.Codex
      assert Classify.resolve_adapter(:openai) == PortfolioIndex.Adapters.LLM.OpenAI
      assert Classify.resolve_adapter(:ollama) == PortfolioIndex.Adapters.LLM.Ollama
    end
  end
end
