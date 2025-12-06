# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-15

### Added

- Initial release of Synapse.AI
- SDK-backed LLM providers implementing Synapse.LLMProvider behaviour
  - `Synapse.AI.Providers.GeminiSDK` - Gemini via altar_ai
  - `Synapse.AI.Providers.ClaudeSDK` - Claude via altar_ai
  - `Synapse.AI.Providers.CodexSDK` - OpenAI via altar_ai
  - `Synapse.AI.Providers.CompositeSDK` - Multi-provider with fallback
- Workflow actions for AI operations
  - `Synapse.AI.Actions.Generate` - Text generation action
  - `Synapse.AI.Actions.Classify` - Classification action
  - `Synapse.AI.Actions.Embed` - Embedding action
- Signal handlers for AI events
  - `Synapse.AI.Signals.AIRequestHandler`
  - `Synapse.AI.Signals.AIResultHandler`
- `Synapse.AI.Telemetry` - Telemetry bridge from altar_ai to Synapse
- Comprehensive test suite

### Features

- Drop-in replacement for Synapse LLM providers
- Automatic provider fallback via Composite adapter
- Integration with Synapse signal bus
- Workflow actions for declarative AI operations
- Telemetry integration for observability
- Runtime capability detection

[0.1.0]: https://github.com/nshkrdotcom/synapse_ai/releases/tag/v0.1.0
