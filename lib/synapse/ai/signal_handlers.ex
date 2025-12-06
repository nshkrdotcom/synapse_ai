defmodule Synapse.AI.SignalHandlers do
  @moduledoc """
  Pre-built signal handlers for common AI operations.

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

  @doc """
  Handler that classifies incoming signals and routes based on classification.

  ## Options

  - `:adapter` - The AI adapter to use (default: Composite)
  - `:labels` - List of classification labels (required)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:route_prefix` - Prefix for routed topics (default: "classified_")

  ## Examples

      # Routes to :classified_urgent, :classified_normal, or :classified_spam
      classify_and_route(signal, labels: ["urgent", "normal", "spam"])
  """
  def classify_and_route(signal, opts) do
    adapter = Keyword.get(opts, :adapter, Altar.AI.Adapters.Composite.default())
    labels = Keyword.fetch!(opts, :labels)
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    route_prefix = Keyword.get(opts, :route_prefix, "classified_")

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:route, :classification_failed, signal}
    else
      case Altar.AI.classify(adapter, text, labels) do
        {:ok, classification} ->
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
  end

  @doc """
  Handler that enriches signals with vector embeddings.

  ## Options

  - `:adapter` - The AI adapter to use (default: Composite)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:embedding_key` - Key to store embeddings under (default: :embedding)

  ## Examples

      enrich_with_embeddings(signal, text_path: [:data, :content])
  """
  def enrich_with_embeddings(signal, opts) do
    adapter = Keyword.get(opts, :adapter, Altar.AI.Adapters.Composite.default())
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    embedding_key = Keyword.get(opts, :embedding_key, :embedding)

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:continue, signal}
    else
      case Altar.AI.embed(adapter, text) do
        {:ok, vector} ->
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
  end

  @doc """
  Handler that generates summaries for text content in signals.

  ## Options

  - `:adapter` - The AI adapter to use (default: Composite)
  - `:text_path` - Path to extract text from signal (default: [:data, :text])
  - `:summary_key` - Key to store summary under (default: :summary)
  - `:max_length` - Maximum summary length in words (optional)

  ## Examples

      generate_summary(signal, text_path: [:data, :article], max_length: 100)
  """
  def generate_summary(signal, opts) do
    adapter = Keyword.get(opts, :adapter, Altar.AI.Adapters.Composite.default())
    text_path = Keyword.get(opts, :text_path, [:data, :text])
    summary_key = Keyword.get(opts, :summary_key, :summary)
    max_length = Keyword.get(opts, :max_length)

    text = get_in(signal, text_path)

    if is_nil(text) do
      Logger.warning("No text found at path #{inspect(text_path)} in signal")
      {:continue, signal}
    else
      prompt = build_summary_prompt(text, max_length)

      case Altar.AI.generate(adapter, prompt) do
        {:ok, response} ->
          updated_signal =
            signal
            |> put_in([summary_key], response.content)
            |> Map.update(:metadata, %{}, fn meta ->
              Map.merge(meta, %{
                summarized_at: DateTime.utc_now(),
                summary_tokens: response.tokens.total
              })
            end)

          {:continue, updated_signal}

        {:error, error} ->
          Logger.error("Summary generation failed: #{inspect(error)}")
          {:continue, Map.put(signal, :summary_error, error)}
      end
    end
  end

  defp build_summary_prompt(text, nil) do
    "Provide a concise summary of the following text:\n\n#{text}"
  end

  defp build_summary_prompt(text, max_length) do
    "Provide a concise summary (maximum #{max_length} words) of the following text:\n\n#{text}"
  end
end
