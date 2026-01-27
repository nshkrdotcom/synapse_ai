defmodule Synapse.AI.Test.MockAdapter do
  @moduledoc """
  Mock adapter for testing synapse_ai without real API calls.

  Implements the `PortfolioCore.Ports.LLM` behaviour for use in tests.
  """

  @behaviour PortfolioCore.Ports.LLM

  defstruct [:config, :responses]

  def new(opts \\ []) do
    %__MODULE__{
      config: Keyword.get(opts, :config, []),
      responses: Keyword.get(opts, :responses, %{})
    }
  end

  def available?, do: true

  @impl true
  def complete(messages, opts \\ []) do
    prompt =
      case messages do
        [%{content: content} | _] -> content
        _ -> ""
      end

    {:ok,
     %{
       content: "Mock response for: #{prompt}",
       model: Keyword.get(opts, :model, "mock-model"),
       usage: %{input_tokens: 5, output_tokens: 5},
       finish_reason: :stop
     }}
  end

  @impl true
  def stream(messages, opts \\ []) do
    case complete(messages, opts) do
      {:ok, response} ->
        {:ok, [response.content]}

      error ->
        error
    end
  end

  @impl true
  def supported_models do
    ["mock-model"]
  end

  @impl true
  def model_info(_model) do
    {:ok,
     %{
       name: "mock-model",
       context_window: 4096,
       max_output_tokens: 1024
     }}
  end
end
