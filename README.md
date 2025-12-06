<div align="center">
  <img src="assets/synapse_ai.svg" alt="Synapse.AI Logo" width="200"/>

  # Synapse.AI

  **SDK-backed LLM providers for Synapse multi-agent workflows**

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
  [![Elixir](https://img.shields.io/badge/Elixir-1.18+-purple.svg)](https://elixir-lang.org)
  [![GitHub](https://img.shields.io/badge/GitHub-synapse__ai-black.svg)](https://github.com/nshkrdotcom/synapse_ai)
</div>

---

## Overview

**Synapse.AI** is a bridge between [altar_ai](https://github.com/nshkrdotcom/altar_ai) and [Synapse](https://github.com/nshkrdotcom/synapse), providing SDK-backed LLM providers and workflow actions for AI-powered multi-agent systems.

### Why Synapse.AI?

Unlike HTTP-based providers, Synapse.AI leverages the full power of native SDKs through altar_ai:

- **Full SDK Features**: Caching, streaming, batch processing, auth management
- **Automatic Fallback**: Composite adapter chains across Gemini, Claude, and Codex
- **Unified Interface**: Single API across all LLM providers
- **Type Safety**: Structured responses and error handling
- **Telemetry Integration**: Unified metrics with FlowStone and other altar_ai consumers

## Installation

Add `synapse_ai` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:synapse_ai, path: "../synapse_ai"},
    # Or from Hex (when published)
    # {:synapse_ai, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Configure Providers

Configure SDK-backed providers in your Synapse ReqLLM profiles:

```elixir
# config/config.exs
config :synapse, Synapse.ReqLLM,
  profiles: %{
    # Gemini with full SDK support
    gemini_sdk: [
      provider_module: Synapse.AI.Providers.GeminiSDK,
      model: "gemini-pro"
    ],

    # Claude with extended thinking and caching
    claude_sdk: [
      provider_module: Synapse.AI.Providers.ClaudeSDK,
      model: "claude-opus-4-5-20251101"
    ],

    # OpenAI Codex for code generation
    codex_sdk: [
      provider_module: Synapse.AI.Providers.CodexSDK,
      model: "gpt-4o"
    ],

    # Composite with automatic fallback
    composite: [
      provider_module: Synapse.AI.Providers.CompositeSDK,
      fallback_order: [:gemini, :claude, :codex]
    ]
  }
```

### 2. Enable Telemetry

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Forward altar_ai telemetry to synapse.ai namespace
    Synapse.AI.setup_telemetry()

    # ... rest of your application setup
  end
end
```

### 3. Use in Workflows

```elixir
alias Synapse.Workflow.{Spec, Step}

Spec.new(
  name: :content_moderation,
  steps: [
    Step.new(
      id: :classify_content,
      action: Synapse.AI.Actions.Classify,
      params: %{
        text: "This is a test message",
        labels: ["safe", "spam", "toxic"],
        adapter: :gemini
      }
    ),
    Step.new(
      id: :generate_response,
      action: Synapse.AI.Actions.Generate,
      params: fn env ->
        case env.classify_content.label do
          "safe" -> %{prompt: "Generate a friendly greeting"}
          "spam" -> %{prompt: "Generate a spam warning"}
          "toxic" -> %{prompt: "Generate a moderation notice"}
        end
      end
    )
  ]
)
```

## Core Components

### SDK-Backed Providers

Implement `Synapse.LLMProvider` but delegate to altar_ai adapters:

- **`Synapse.AI.Providers.GeminiSDK`**: Full gemini_ex SDK with caching and streaming
- **`Synapse.AI.Providers.ClaudeSDK`**: Full claude_agent_sdk with extended thinking
- **`Synapse.AI.Providers.CodexSDK`**: Full OpenAI SDK for code generation
- **`Synapse.AI.Providers.CompositeSDK`**: Automatic fallback across all providers

### Workflow Actions

Jido Actions for AI operations in Synapse workflows:

#### Generate

Text generation with any adapter:

```elixir
Step.new(
  id: :summarize,
  action: Synapse.AI.Actions.Generate,
  params: %{
    prompt: "Summarize the following article: #{article_text}",
    adapter: :claude,
    opts: [max_tokens: 500]
  }
)
```

#### Classify

Multi-label classification:

```elixir
Step.new(
  id: :classify_sentiment,
  action: Synapse.AI.Actions.Classify,
  params: %{
    text: user_feedback,
    labels: ["positive", "negative", "neutral"],
    adapter: :gemini
  }
)
```

#### Embed

Vector embedding generation:

```elixir
Step.new(
  id: :embed_documents,
  action: Synapse.AI.Actions.Embed,
  params: %{
    texts: documents,
    adapter: :composite
  }
)
```

### Signal Handlers

Pre-built handlers for signal-driven AI operations:

#### Classify and Route

Automatically route signals based on classification:

```elixir
Synapse.SignalRouter.register_handler(
  :incoming_messages,
  &Synapse.AI.SignalHandlers.classify_and_route/2,
  labels: ["urgent", "normal", "spam"],
  text_path: [:data, :message, :body],
  route_prefix: "classified_"
)
```

#### Enrich with Embeddings

Add vector embeddings to signals:

```elixir
Synapse.SignalRouter.register_handler(
  :documents,
  &Synapse.AI.SignalHandlers.enrich_with_embeddings/2,
  text_path: [:data, :content],
  adapter: :gemini
)
```

#### Generate Summary

Automatically summarize text content:

```elixir
Synapse.SignalRouter.register_handler(
  :articles,
  &Synapse.AI.SignalHandlers.generate_summary/2,
  text_path: [:data, :article],
  max_length: 100
)
```

## Telemetry

Synapse.AI bridges altar_ai telemetry events to the `:synapse, :ai` namespace:

```elixir
:telemetry.attach(
  "my-handler",
  [:synapse, :ai, :generate, :stop],
  fn _event, measurements, metadata, _config ->
    IO.puts("Generated #{metadata.model} in #{measurements.duration}ms")
  end,
  nil
)
```

### Available Events

- `[:synapse, :ai, :generate, :start | :stop | :exception]`
- `[:synapse, :ai, :classify, :start | :stop | :exception]`
- `[:synapse, :ai, :embed, :start | :stop | :exception]`
- `[:synapse, :ai, :batch_embed, :start | :stop | :exception]`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Synapse Workflows                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Generate   │  │   Classify   │  │    Embed     │ │
│  │    Action    │  │    Action    │  │   Action     │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   Synapse.AI     │
                    │   Providers      │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │    Altar.AI      │
                    │    Adapters      │
                    └────────┬─────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
    ┌─────▼─────┐     ┌─────▼─────┐     ┌─────▼─────┐
    │  Gemini   │     │  Claude   │     │   Codex   │
    │    SDK    │     │    SDK    │     │    SDK    │
    └───────────┘     └───────────┘     └───────────┘
```

## Benefits Over HTTP-Based Providers

| Feature | HTTP Providers | Synapse.AI (SDK) |
|---------|---------------|------------------|
| Streaming | Limited | Full support |
| Caching | None | Provider-native |
| Auth Management | Manual | SDK-handled |
| Rate Limiting | Manual | SDK-handled |
| Retry Logic | Manual | SDK-native |
| Fallback Chains | Manual | Automatic |
| Type Safety | Partial | Full |
| Error Handling | Custom | Unified |

## Examples

### Multi-Model Pipeline

```elixir
Spec.new(
  name: :multi_model_pipeline,
  steps: [
    # Fast classification with Gemini
    Step.new(
      id: :classify,
      action: Synapse.AI.Actions.Classify,
      params: %{text: input, labels: ["code", "text"], adapter: :gemini}
    ),

    # Code generation with Codex if needed
    Step.new(
      id: :generate_code,
      action: Synapse.AI.Actions.Generate,
      when: fn env -> env.classify.label == "code" end,
      params: %{prompt: "Generate code for: #{input}", adapter: :codex}
    ),

    # Text refinement with Claude otherwise
    Step.new(
      id: :refine_text,
      action: Synapse.AI.Actions.Generate,
      when: fn env -> env.classify.label == "text" end,
      params: %{prompt: "Refine: #{input}", adapter: :claude}
    )
  ]
)
```

### Automatic Fallback

```elixir
# Use composite adapter for automatic failover
Step.new(
  id: :resilient_generation,
  action: Synapse.AI.Actions.Generate,
  params: %{
    prompt: "Critical task: #{task}",
    adapter: :composite  # Will try Gemini -> Claude -> Codex
  }
)
```

## Testing

Run the test suite:

```bash
mix test
```

All tests use async execution and mock adapters for fast, reliable testing.

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `mix test` and `mix format` pass
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- **GitHub**: https://github.com/nshkrdotcom/synapse_ai
- **Related Projects**:
  - [altar_ai](https://github.com/nshkrdotcom/altar_ai) - Unified LLM adapter layer
  - [Synapse](https://github.com/nshkrdotcom/synapse) - Multi-agent workflow engine
  - [FlowStone](https://github.com/nshkrdotcom/flowstone) - Data pipeline framework

---

<div align="center">
  Built with Elixir | Powered by altar_ai | Integrated with Synapse
</div>
