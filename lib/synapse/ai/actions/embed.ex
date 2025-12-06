defmodule Synapse.AI.Actions.Embed do
  @moduledoc """
  Jido Action for embedding generation in Synapse workflows.

  Generates vector embeddings for text using AI models.

  ## Usage in Workflow

      Spec.new(
        name: :embedding_workflow,
        steps: [
          Step.new(
            id: :generate_embeddings,
            action: Synapse.AI.Actions.Embed,
            params: fn env -> %{
              texts: env.input.documents,
              adapter: :gemini
            } end
          )
        ]
      )

  ## Parameters

  - `:text` - A single text to embed (either this or `:texts` required)
  - `:texts` - A list of texts to embed (either this or `:text` required)
  - `:adapter` - Which adapter to use: `:gemini`, `:claude`, `:codex`, `:composite` (default: `:composite`)
  - `:opts` - Additional options to pass to the adapter (optional)

  ## Returns

  A map containing:
  - `:embeddings` - List of embedding vectors (one per input text)
  """

  use Jido.Action,
    name: "embed",
    description: "AI embedding generation action",
    schema: [
      text: [type: :string, required: false],
      texts: [type: {:list, :string}, required: false],
      adapter: [type: :atom, required: false],
      opts: [type: :keyword_list, required: false]
    ]

  @impl true
  def run(params, _context) do
    adapter = get_adapter(params[:adapter])
    texts = extract_texts(params)

    if is_nil(texts) or texts == [] do
      {:error, %Jido.Error{type: :validation_error, message: "text or texts is required"}}
    else
      opts = Map.get(params, :opts, [])

      case Altar.AI.batch_embed(adapter, texts, opts) do
        {:ok, vectors} ->
          {:ok, %{embeddings: vectors}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp extract_texts(params) do
    cond do
      text = params[:text] ->
        List.wrap(text)

      texts = params[:texts] ->
        List.wrap(texts)

      true ->
        nil
    end
  end

  defp get_adapter(:gemini), do: Altar.AI.Adapters.Gemini.new()
  defp get_adapter(:claude), do: Altar.AI.Adapters.Claude.new()
  defp get_adapter(:codex), do: Altar.AI.Adapters.Codex.new()
  defp get_adapter(:composite), do: Altar.AI.Adapters.Composite.default()
  defp get_adapter(nil), do: Altar.AI.Adapters.Composite.default()

  defp get_adapter(adapter) when is_struct(adapter) do
    # Allow passing an adapter struct directly
    adapter
  end
end
