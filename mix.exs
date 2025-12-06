defmodule Synapse.AI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/synapse_ai"

  def project do
    [
      app: :synapse_ai,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      name: "SynapseAI",
      description: description(),
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies (path for dev, will be hex for release)
      {:altar_ai, path: "../altar_ai"},
      {:synapse, path: "../synapse"},
      {:jido, "~> 1.0"},

      # Test dependencies
      {:supertester, path: "../supertester", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Synapse integration for altar_ai - SDK-backed LLM providers for multi-agent workflows.
    Provides unified adapter layer for Gemini, Claude, and Codex with automatic fallback,
    workflow actions, signal handlers, and telemetry bridging.
    """
  end

  defp package do
    [
      name: "synapse_ai",
      maintainers: ["nshkrdotcom"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md assets),
      exclude_patterns: [
        "priv/plts",
        ".DS_Store"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "SynapseAI",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      logo: "assets/synapse_ai.svg",
      assets: %{"assets" => "assets"},
      extras: ["README.md", "LICENSE", "CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [Synapse.AI],
        Providers: [
          Synapse.AI.Providers.GeminiSDK,
          Synapse.AI.Providers.ClaudeSDK,
          Synapse.AI.Providers.CodexSDK,
          Synapse.AI.Providers.CompositeSDK
        ],
        Actions: [
          Synapse.AI.Actions.Generate,
          Synapse.AI.Actions.Classify,
          Synapse.AI.Actions.Embed
        ],
        Signals: [
          Synapse.AI.Signals.AIRequestHandler,
          Synapse.AI.Signals.AIResultHandler
        ],
        Utilities: [Synapse.AI.Telemetry]
      ]
    ]
  end
end
