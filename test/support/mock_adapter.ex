defmodule Synapse.AI.Test.MockAdapter do
  @moduledoc """
  Mock adapter for testing synapse_ai without real API calls.
  """

  defstruct [:config, :responses]

  def new(opts \\ []) do
    %__MODULE__{
      config: Keyword.get(opts, :config, []),
      responses: Keyword.get(opts, :responses, %{})
    }
  end

  def available?, do: true

  def generate(%__MODULE__{responses: responses}, prompt, _opts) do
    case Map.get(responses, :generate) do
      nil ->
        {:ok,
         %Altar.AI.Response{
           content: "Mock response for: #{prompt}",
           provider: :mock,
           model: "mock-model",
           tokens: %{total: 10, prompt: 5, completion: 5},
           finish_reason: :stop
         }}

      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}

      fun when is_function(fun, 1) ->
        fun.(prompt)
    end
  end

  def classify(%__MODULE__{responses: responses}, text, labels, _opts) do
    case Map.get(responses, :classify) do
      nil ->
        # Default: return first label with 0.9 confidence
        {:ok,
         %{
           label: List.first(labels),
           confidence: 0.9,
           all_scores: Enum.into(labels, %{}, fn label -> {label, 0.9 / length(labels)} end)
         }}

      {:ok, classification} ->
        {:ok, classification}

      {:error, error} ->
        {:error, error}

      fun when is_function(fun, 2) ->
        fun.(text, labels)
    end
  end

  def embed(%__MODULE__{responses: responses}, text, _opts) do
    case Map.get(responses, :embed) do
      nil ->
        # Default: return random vector
        {:ok, Enum.map(1..128, fn _ -> :rand.uniform() end)}

      {:ok, vector} ->
        {:ok, vector}

      {:error, error} ->
        {:error, error}

      fun when is_function(fun, 1) ->
        fun.(text)
    end
  end

  def batch_embed(%__MODULE__{responses: responses}, texts, _opts) do
    case Map.get(responses, :batch_embed) do
      nil ->
        # Default: return random vectors for each text
        vectors = Enum.map(texts, fn _ -> Enum.map(1..128, fn _ -> :rand.uniform() end) end)
        {:ok, vectors}

      {:ok, vectors} ->
        {:ok, vectors}

      {:error, error} ->
        {:error, error}

      fun when is_function(fun, 1) ->
        fun.(texts)
    end
  end
end
