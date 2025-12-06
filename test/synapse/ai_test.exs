defmodule Synapse.AITest do
  use ExUnit.Case, async: true

  alias Synapse.AI

  describe "setup_telemetry/0" do
    test "sets up telemetry bridge" do
      # Verify function exists
      assert function_exported?(Synapse.AI, :setup_telemetry, 0)
    end
  end

  describe "available_providers/0" do
    test "returns list of available providers" do
      providers = Synapse.AI.available_providers()
      assert is_list(providers)

      # CompositeSDK should always be available
      assert Synapse.AI.Providers.CompositeSDK in providers
    end

    test "all returned providers are modules" do
      providers = Synapse.AI.available_providers()

      Enum.each(providers, fn provider ->
        assert is_atom(provider)
        assert Code.ensure_loaded?(provider)
      end)
    end
  end

  describe "version/0" do
    test "returns version string" do
      version = Synapse.AI.version()
      assert is_binary(version)
      assert version =~ ~r/\d+\.\d+\.\d+/
    end
  end

  describe "ready?/0" do
    test "checks if synapse_ai is ready" do
      ready = Synapse.AI.ready?()
      assert is_boolean(ready)
    end
  end
end
