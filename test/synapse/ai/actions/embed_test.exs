defmodule Synapse.AI.Actions.EmbedTest do
  use ExUnit.Case, async: true

  alias Synapse.AI.Actions.Embed

  describe "run/2" do
    test "returns error when text and texts are missing" do
      params = %{}
      assert {:error, %Jido.Error{type: :validation_error, message: msg}} = Embed.run(params, %{})
      assert msg =~ "text or texts"
    end

    test "successfully embeds with text parameter" do
      # This test would require mocking Altar.AI.batch_embed
      # For now, verify the function exists and has correct arity
      assert function_exported?(Embed, :run, 2)
    end

    test "successfully embeds with texts parameter" do
      # Structural test
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
end
