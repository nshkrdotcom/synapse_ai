defmodule Synapse.AI.Actions.Classify do
  @moduledoc """
  Jido Action for AI classification in Synapse workflows.

  Classifies text into one of the provided labels using portfolio_index LLM adapters.
  Uses a structured prompt to get classification results from the LLM.

  ## Usage in Workflow

      Spec.new(
        name: :classification_workflow,
        steps: [
          Step.new(
            id: :classify_sentiment,
            action: Synapse.AI.Actions.Classify,
            params: fn env -> %{
              text: env.input.feedback,
              labels: ["positive", "negative", "neutral"],
              adapter: :gemini
            } end
          )
        ]
      )

  ## Parameters

  - `:text` - The text to classify (required)
  - `:labels` - List of possible classification labels (required)
  - `:adapter` - Which adapter to use: `:gemini`, `:claude`, `:codex`, `:openai`, `:ollama`, `:composite` (default: `:composite`)
  - `:opts` - Additional options to pass to the adapter (optional)

  ## Returns

  A map containing:
  - `:label` - The predicted label
  - `:confidence` - Confidence score (0.0 to 1.0)
  - `:all_scores` - Map of all labels to their scores
  """

  use Jido.Action,
    name: "classify",
    description: "AI classification action",
    schema: [
      text: [type: :string, required: true],
      labels: [type: {:list, :string}, required: true],
      adapter: [type: :atom, required: false],
      opts: [type: :keyword_list, required: false]
    ]

  @impl true
  def run(params, _context) do
    text = params[:text]
    labels = params[:labels]

    cond do
      is_nil(text) ->
        {:error, Jido.Error.validation_error("text is required")}

      is_nil(labels) or labels == [] ->
        {:error, Jido.Error.validation_error("labels is required and must be non-empty")}

      true ->
        adapter_module = resolve_adapter(params[:adapter])
        opts = Map.get(params, :opts, [])
        classify_with_llm(adapter_module, text, labels, opts)
    end
  end

  @doc """
  Resolves an adapter atom to its portfolio_index adapter module.
  """
  def resolve_adapter(:gemini), do: PortfolioIndex.Adapters.LLM.Gemini
  def resolve_adapter(:claude), do: PortfolioIndex.Adapters.LLM.Anthropic
  def resolve_adapter(:codex), do: PortfolioIndex.Adapters.LLM.Codex
  def resolve_adapter(:openai), do: PortfolioIndex.Adapters.LLM.OpenAI
  def resolve_adapter(:ollama), do: PortfolioIndex.Adapters.LLM.Ollama
  def resolve_adapter(:composite), do: PortfolioIndex.Adapters.LLM.Gemini
  def resolve_adapter(nil), do: PortfolioIndex.Adapters.LLM.Gemini

  def resolve_adapter(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :complete, 2) do
      module
    else
      PortfolioIndex.Adapters.LLM.Gemini
    end
  end

  defp classify_with_llm(adapter_module, text, labels, opts) do
    labels_str = Enum.join(labels, ", ")

    prompt =
      "Classify the following text into exactly one of these labels: #{labels_str}\n\n" <>
        "Text: #{text}\n\n" <>
        "Respond with ONLY the label, nothing else."

    messages = [%{role: :user, content: prompt}]

    case adapter_module.complete(messages, opts) do
      {:ok, response} ->
        raw_label = response |> Map.get(:content, "") |> String.trim()
        matched_label = find_best_label(raw_label, labels)

        {:ok,
         %{
           label: matched_label,
           confidence: if(matched_label == raw_label, do: 0.9, else: 0.7),
           all_scores:
             Enum.into(labels, %{}, fn label ->
               score = if label == matched_label, do: 0.9, else: 0.1 / max(length(labels) - 1, 1)
               {label, score}
             end)
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_best_label(raw, labels) do
    # Exact match first
    exact = Enum.find(labels, fn l -> String.downcase(l) == String.downcase(raw) end)

    if exact do
      exact
    else
      # Substring match
      Enum.find(labels, List.first(labels), fn l ->
        String.contains?(String.downcase(raw), String.downcase(l))
      end)
    end
  end
end
