defmodule Synapse.AI.Actions.Generate do
  @moduledoc """
  Jido Action for AI text generation in Synapse workflows.

  ## Usage in Workflow

      Spec.new(
        name: :ai_workflow,
        steps: [
          Step.new(
            id: :generate_summary,
            action: Synapse.AI.Actions.Generate,
            params: fn env -> %{
              prompt: "Summarize: \#{env.input.text}",
              adapter: :gemini
            } end
          )
        ]
      )

  ## Parameters

  - `:prompt` - The text prompt for generation (required)
  - `:adapter` - Which adapter to use: `:gemini`, `:claude`, `:codex`, `:composite` (default: `:composite`)
  - `:opts` - Additional options to pass to the adapter (optional)

  ## Returns

  A map containing:
  - `:content` - The generated text
  - `:model` - The model used for generation
  - `:tokens` - Token usage information
  """

  use Jido.Action,
    name: "generate",
    description: "AI text generation action",
    schema: [
      prompt: [type: :string, required: true],
      adapter: [type: :atom, required: false],
      opts: [type: :keyword_list, required: false]
    ]

  @impl true
  def run(params, _context) do
    adapter = get_adapter(params[:adapter])
    prompt = params[:prompt]

    unless prompt do
      {:error, %Jido.Error{type: :validation_error, message: "prompt is required"}}
    else
      opts = Map.get(params, :opts, [])

      case Altar.AI.generate(adapter, prompt, opts) do
        {:ok, response} ->
          {:ok,
           %{
             content: response.content,
             model: response.model,
             tokens: response.tokens
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
