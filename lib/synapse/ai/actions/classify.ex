defmodule Synapse.AI.Actions.Classify do
  @moduledoc """
  Jido Action for AI classification in Synapse workflows.

  Classifies text into one of the provided labels using AI.

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
  - `:adapter` - Which adapter to use: `:gemini`, `:claude`, `:codex`, `:composite` (default: `:composite`)
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
    adapter = get_adapter(params[:adapter])
    text = params[:text]
    labels = params[:labels]

    cond do
      is_nil(text) ->
        {:error, %Jido.Error{type: :validation_error, message: "text is required"}}

      is_nil(labels) or labels == [] ->
        {:error,
         %Jido.Error{type: :validation_error, message: "labels is required and must be non-empty"}}

      true ->
        opts = Map.get(params, :opts, [])

        case Altar.AI.classify(adapter, text, labels, opts) do
          {:ok, classification} ->
            {:ok,
             %{
               label: classification.label,
               confidence: classification.confidence,
               all_scores: classification.all_scores
             }}

          {:error, error} ->
            {:error, error}
        end
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
