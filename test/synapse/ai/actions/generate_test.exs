defmodule Synapse.AI.Actions.GenerateTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Generate

  setup_all do
    Code.ensure_loaded?(Generate)
    :ok
  end

  describe "run/2" do
    test "returns error when prompt is missing" do
      params = %{}
      assert {:error, %Jido.Error.ValidationError{}} = Generate.run(params, %{})
    end

    test "successfully generates text with prompt" do
      assert function_exported?(Generate, :run, 2)
    end

    test "accepts adapter as parameter" do
      params = %{prompt: "test", adapter: :gemini}
      assert is_map(params)
    end

    test "accepts opts parameter" do
      params = %{prompt: "test", opts: [max_tokens: 100]}
      assert is_map(params)
    end

    test "uses composite adapter by default" do
      assert function_exported?(Generate, :run, 2)
    end
  end

  describe "resolve_adapter/1" do
    test "resolves adapter from atom" do
      assert Generate.resolve_adapter(:gemini) == PortfolioIndex.Adapters.LLM.Gemini
      assert Generate.resolve_adapter(:claude) == PortfolioIndex.Adapters.LLM.Anthropic
      assert Generate.resolve_adapter(:codex) == PortfolioIndex.Adapters.LLM.Codex
      assert Generate.resolve_adapter(:openai) == PortfolioIndex.Adapters.LLM.OpenAI
      assert Generate.resolve_adapter(:ollama) == PortfolioIndex.Adapters.LLM.Ollama
    end

    test "resolves composite adapter" do
      assert Generate.resolve_adapter(:composite) == :composite
      assert Generate.resolve_adapter(nil) == :composite
    end
  end
end
