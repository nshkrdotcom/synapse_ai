defmodule Synapse.AI.SignalHandlers do
  @moduledoc """
  Pre-built signal handlers for common AI operations.

  Uses portfolio_index adapters for AI-powered signal processing.
  Register with SignalRouter to enable AI-powered signal processing.

  ## Example: Classify and Route

      Synapse.SignalRouter.register_handler(
        :incoming_messages,
        &Synapse.AI.SignalHandlers.classify_and_route/2,
        labels: ["urgent", "normal", "spam"],
        text_path: [:data, :message, :body]
      )

  ## Example: Enrich with Embeddings

      Synapse.SignalRouter.register_handler(
        :documents,
        &Synapse.AI.SignalHandlers.enrich_with_embeddings/2,
        text_path: [:data, :content],
        adapter: :gemini
      )
  """

  require Logger

  @default_llm_adapter PortfolioIndex.Adapters.LLM.Gemini
  @default_embedder_adapter PortfolioIndex.Adapters.Embedder.Gemini

  @doc """
  Handler that classifies incoming signals and routes based on classification.

  ## Options

  - `:adapter` - The AI adapter atom or module (default: :gemini)
  - `:labels` - List of classification labels (required)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:route_prefix` - Prefix for routed topics (default: "classified_")

  ## Examples

      # Routes to :classified_urgent, :classified_normal, or :classified_spam
      classify_and_route(signal, labels: ["urgent", "normal", "spam"])
  """
  def classify_and_route(signal, opts) do
    adapter = resolve_llm_adapter(Keyword.get(opts, :adapter))
    labels = Keyword.fetch!(opts, :labels)
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    route_prefix = Keyword.get(opts, :route_prefix, "classified_")

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:route, :classification_failed, signal}
    else
      do_classify_and_route(signal, text, adapter, labels, route_prefix)
    end
  end

  defp do_classify_and_route(signal, text, adapter, labels, route_prefix) do
    labels_str = Enum.join(labels, ", ")

    prompt =
      "Classify the following text into exactly one of these labels: #{labels_str}\n\n" <>
        "Text: #{text}\n\nRespond with ONLY the label, nothing else."

    messages = [%{role: :user, content: prompt}]

    case adapter.complete(messages, []) do
      {:ok, response} ->
        raw_label = response |> Map.get(:content, "") |> String.trim()

        matched_label =
          Enum.find(labels, List.first(labels), fn l ->
            String.downcase(l) == String.downcase(raw_label)
          end)

        classification = build_classification(matched_label, raw_label, labels)
        route_topic = String.to_atom("#{route_prefix}#{classification.label}")

        updated_signal =
          signal
          |> Map.put(:classification, classification)
          |> Map.update(:metadata, %{}, fn meta ->
            Map.merge(meta, %{
              classified_at: DateTime.utc_now(),
              classification_label: classification.label,
              classification_confidence: classification.confidence
            })
          end)

        {:route, route_topic, updated_signal}

      {:error, error} ->
        Logger.error("Classification failed: #{inspect(error)}")
        {:route, :classification_failed, Map.put(signal, :error, error)}
    end
  end

  defp build_classification(matched_label, raw_label, labels) do
    %{
      label: matched_label,
      confidence: if(matched_label == raw_label, do: 0.9, else: 0.7),
      all_scores:
        Enum.into(labels, %{}, fn label ->
          score =
            if label == matched_label,
              do: 0.9,
              else: 0.1 / max(length(labels) - 1, 1)

          {label, score}
        end)
    }
  end

  @doc """
  Handler that enriches signals with vector embeddings.

  ## Options

  - `:adapter` - The embedder adapter atom or module (default: :gemini)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:embedding_key` - Key to store embeddings under (default: :embedding)

  ## Examples

      enrich_with_embeddings(signal, text_path: [:data, :content])
  """
  def enrich_with_embeddings(signal, opts) do
    embedder = resolve_embedder_adapter(Keyword.get(opts, :adapter))
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    embedding_key = Keyword.get(opts, :embedding_key, :embedding)

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:continue, signal}
    else
      do_enrich_with_embeddings(signal, text, embedder, embedding_key)
    end
  end

  defp do_enrich_with_embeddings(signal, text, embedder, embedding_key) do
    case embedder.embed(text, []) do
      {:ok, %{vector: vector}} ->
        updated_signal =
          signal
          |> put_in([embedding_key], vector)
          |> Map.update(:metadata, %{}, fn meta ->
            Map.put(meta, :embedded_at, DateTime.utc_now())
          end)

        {:continue, updated_signal}

      {:error, error} ->
        Logger.error("Embedding generation failed: #{inspect(error)}")
        {:continue, Map.put(signal, :embedding_error, error)}
    end
  end

  @doc """
  Handler that generates summaries for text content in signals.

  ## Options

  - `:adapter` - The AI adapter atom or module (default: :gemini)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:summary_key` - Key to store summary under (default: :summary)
  - `:max_length` - Maximum summary length in words (optional)

  ## Examples

      generate_summary(signal, text_path: [:data, :article], max_length: 100)
  """
  def generate_summary(signal, opts) do
    adapter = resolve_llm_adapter(Keyword.get(opts, :adapter))
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    summary_key = Keyword.get(opts, :summary_key, :summary)
    max_length = Keyword.get(opts, :max_length)

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:continue, signal}
    else
      do_generate_summary(signal, text, adapter, summary_key, max_length)
    end
  end

  defp do_generate_summary(signal, text, adapter, summary_key, max_length) do
    prompt = build_summary_prompt(text, max_length)
    messages = [%{role: :user, content: prompt}]

    case adapter.complete(messages, []) do
      {:ok, response} ->
        content = Map.get(response, :content, "")
        usage = Map.get(response, :usage, %{})

        total_tokens =
          Map.get(usage, :input_tokens, 0) + Map.get(usage, :output_tokens, 0)

        updated_signal =
          signal
          |> put_in([summary_key], content)
          |> Map.update(:metadata, %{}, fn meta ->
            Map.merge(meta, %{
              summarized_at: DateTime.utc_now(),
              summary_tokens: total_tokens
            })
          end)

        {:continue, updated_signal}

      {:error, error} ->
        Logger.error("Summary generation failed: #{inspect(error)}")
        {:continue, Map.put(signal, :summary_error, error)}
    end
  end

  defp build_summary_prompt(text, nil) do
    "Provide a concise summary of the following text:\n\n#{text}"
  end

  defp build_summary_prompt(text, max_length) do
    "Provide a concise summary (maximum #{max_length} words) of the following text:\n\n#{text}"
  end

  defp resolve_llm_adapter(nil), do: @default_llm_adapter
  defp resolve_llm_adapter(:gemini), do: PortfolioIndex.Adapters.LLM.Gemini
  defp resolve_llm_adapter(:claude), do: PortfolioIndex.Adapters.LLM.Anthropic
  defp resolve_llm_adapter(:codex), do: PortfolioIndex.Adapters.LLM.Codex
  defp resolve_llm_adapter(:openai), do: PortfolioIndex.Adapters.LLM.OpenAI
  defp resolve_llm_adapter(:ollama), do: PortfolioIndex.Adapters.LLM.Ollama
  defp resolve_llm_adapter(module) when is_atom(module), do: module

  defp resolve_embedder_adapter(nil), do: @default_embedder_adapter
  defp resolve_embedder_adapter(:gemini), do: PortfolioIndex.Adapters.Embedder.Gemini
  defp resolve_embedder_adapter(:openai), do: PortfolioIndex.Adapters.Embedder.OpenAI
  # LLM adapter atoms that don't have embedders fall back to Gemini
  defp resolve_embedder_adapter(:claude), do: PortfolioIndex.Adapters.Embedder.Gemini
  defp resolve_embedder_adapter(:codex), do: PortfolioIndex.Adapters.Embedder.OpenAI
  defp resolve_embedder_adapter(:ollama), do: PortfolioIndex.Adapters.Embedder.Gemini
  defp resolve_embedder_adapter(module) when is_atom(module), do: module
end
