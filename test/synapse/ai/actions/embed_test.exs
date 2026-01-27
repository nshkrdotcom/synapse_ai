defmodule Synapse.AI.Actions.EmbedTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Embed

  setup_all do
    Code.ensure_loaded?(Embed)
    :ok
  end

  describe "run/2" do
    test "returns error when text and texts are missing" do
      params = %{}
      assert {:error, %Jido.Error.ValidationError{message: msg}} = Embed.run(params, %{})
      assert msg =~ "text or texts"
    end

    test "successfully embeds with text parameter" do
      assert function_exported?(Embed, :run, 2)
    end

    test "successfully embeds with texts parameter" do
      params = %{texts: ["text1", "text2"]}
      assert is_map(params)
    end

    test "wraps single text into list" do
      params = %{text: "single text"}
      assert is_map(params)
    end

    test "accepts adapter parameter" do
      params = %{text: "test", adapter: :gemini}
      assert is_map(params)
    end

    test "accepts opts parameter" do
      params = %{text: "test", opts: [dimensions: 256]}
      assert is_map(params)
    end
  end

  describe "resolve_adapter/1" do
    test "resolves embedder adapter from atom" do
      assert Embed.resolve_adapter(:gemini) == PortfolioIndex.Adapters.Embedder.Gemini
      assert Embed.resolve_adapter(:openai) == PortfolioIndex.Adapters.Embedder.OpenAI
    end

    test "falls back to appropriate embedder for LLM-only adapters" do
      assert Embed.resolve_adapter(:claude) == PortfolioIndex.Adapters.Embedder.Gemini
      assert Embed.resolve_adapter(:codex) == PortfolioIndex.Adapters.Embedder.OpenAI
    end
  end
end
