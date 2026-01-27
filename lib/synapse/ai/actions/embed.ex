defmodule Synapse.AI.Actions.Embed do
  @moduledoc """
  Jido Action for embedding generation in Synapse workflows.

  Generates vector embeddings for text using portfolio_index Embedder adapters.

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
  - `:adapter` - Which embedder adapter to use: `:gemini`, `:openai` (default: `:gemini`)
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
    case extract_texts(params) do
      nil -> {:error, Jido.Error.validation_error("text or texts is required")}
      [] -> {:error, Jido.Error.validation_error("text or texts is required")}
      texts -> do_embed(texts, resolve_adapter(params[:adapter]), Map.get(params, :opts, []))
    end
  end

  defp do_embed(texts, embedder, opts) do
    case embedder.embed_batch(texts, opts) do
      {:ok, %{embeddings: embeddings}} ->
        vectors = Enum.map(embeddings, fn e -> Map.get(e, :vector, e) end)
        {:ok, %{embeddings: vectors}}

      {:ok, vectors} when is_list(vectors) ->
        {:ok, %{embeddings: vectors}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Resolves an adapter atom to its portfolio_index embedder module.
  """
  def resolve_adapter(:gemini), do: PortfolioIndex.Adapters.Embedder.Gemini
  def resolve_adapter(:openai), do: PortfolioIndex.Adapters.Embedder.OpenAI
  # LLM adapter atoms that don't have embedders fall back to Gemini embedder
  def resolve_adapter(:claude), do: PortfolioIndex.Adapters.Embedder.Gemini
  def resolve_adapter(:codex), do: PortfolioIndex.Adapters.Embedder.OpenAI
  def resolve_adapter(:ollama), do: PortfolioIndex.Adapters.Embedder.Gemini
  def resolve_adapter(:composite), do: PortfolioIndex.Adapters.Embedder.Gemini
  def resolve_adapter(nil), do: PortfolioIndex.Adapters.Embedder.Gemini

  def resolve_adapter(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :embed, 2) do
      module
    else
      PortfolioIndex.Adapters.Embedder.Gemini
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
end
