defmodule Synapse.AI.Actions.Generate do
  @moduledoc """
  Jido Action for AI text generation in Synapse workflows.

  Uses portfolio_index LLM adapters for text generation.

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
  - `:adapter` - Which adapter to use: `:gemini`, `:claude`, `:codex`, `:openai`, `:ollama`, `:composite` (default: `:composite`)
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

  alias Synapse.AI.Providers.CompositeSDK

  @adapter_map %{
    gemini: PortfolioIndex.Adapters.LLM.Gemini,
    claude: PortfolioIndex.Adapters.LLM.Anthropic,
    codex: PortfolioIndex.Adapters.LLM.Codex,
    openai: PortfolioIndex.Adapters.LLM.OpenAI,
    ollama: PortfolioIndex.Adapters.LLM.Ollama
  }

  @impl true
  def run(%{prompt: prompt} = params, _context) when is_binary(prompt) do
    adapter = resolve_adapter(params[:adapter] || :composite)
    opts = Map.get(params, :opts, [])
    do_generate(adapter, prompt, opts)
  end

  def run(_params, _context) do
    {:error, Jido.Error.validation_error("prompt is required")}
  end

  @doc """
  Resolves an adapter atom to its portfolio_index adapter module.
  """
  def resolve_adapter(:gemini), do: PortfolioIndex.Adapters.LLM.Gemini
  def resolve_adapter(:claude), do: PortfolioIndex.Adapters.LLM.Anthropic
  def resolve_adapter(:codex), do: PortfolioIndex.Adapters.LLM.Codex
  def resolve_adapter(:openai), do: PortfolioIndex.Adapters.LLM.OpenAI
  def resolve_adapter(:ollama), do: PortfolioIndex.Adapters.LLM.Ollama
  def resolve_adapter(:composite), do: :composite
  def resolve_adapter(nil), do: :composite

  def resolve_adapter(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :complete, 2) do
      module
    else
      :composite
    end
  end

  @doc """
  Returns the adapter map for lookup.
  """
  def adapter_map, do: @adapter_map

  defp do_generate(:composite, prompt, opts) do
    case CompositeSDK.chat_completion(%{prompt: prompt}, opts, []) do
      {:ok, response} -> {:ok, format_composite_response(response)}
      {:error, error} -> {:error, error}
    end
  end

  defp do_generate(adapter_module, prompt, opts) do
    messages = [%{role: :user, content: prompt}]

    case adapter_module.complete(messages, opts) do
      {:ok, response} -> {:ok, format_adapter_response(response)}
      {:error, error} -> {:error, error}
    end
  end

  defp format_composite_response(response) do
    %{
      content: response.content,
      model: get_in(response, [:metadata, :model]) || "unknown",
      tokens: %{
        total: get_in(response, [:metadata, :total_tokens]) || 0,
        prompt: get_in(response, [:metadata, :prompt_tokens]) || 0,
        completion: get_in(response, [:metadata, :completion_tokens]) || 0
      }
    }
  end

  defp format_adapter_response(response) do
    %{
      content: Map.get(response, :content, ""),
      model: Map.get(response, :model, "unknown"),
      tokens: %{
        total:
          get_in_usage(response, :input_tokens, 0) + get_in_usage(response, :output_tokens, 0),
        prompt: get_in_usage(response, :input_tokens, 0),
        completion: get_in_usage(response, :output_tokens, 0)
      }
    }
  end

  defp get_in_usage(response, key, default) do
    case Map.get(response, :usage) do
      %{} = usage -> Map.get(usage, key, default)
      _ -> default
    end
  end
end
