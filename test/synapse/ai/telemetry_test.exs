defmodule Synapse.AI.TelemetryTest do
  use ExUnit.Case, async: false

  alias Synapse.AI.Telemetry

  describe "attach/0" do
    test "attaches telemetry handlers" do
      # Detach first if already attached
      try do
        Telemetry.detach()
      rescue
        _ -> :ok
      end

      assert :ok = Telemetry.attach()

      # Verify we can detach (which means it was attached)
      assert :ok = Telemetry.detach()
    end
  end

  describe "detach/0" do
    test "detaches telemetry handlers" do
      # Attach first
      try do
        Telemetry.attach()
      rescue
        _ -> :ok
      end

      assert :ok = Telemetry.detach()
    end
  end

  describe "forwarded_events/0" do
    test "returns list of forwarded events" do
      events = Telemetry.forwarded_events()
      assert is_list(events)
      assert [:portfolio_index, :llm, :complete, :start] in events
      assert [:portfolio_index, :llm, :complete, :stop] in events
      assert [:portfolio_index, :embedder, :embed] in events
    end
  end

  describe "synapse_event/1" do
    test "converts portfolio_index LLM event to synapse event" do
      portfolio_event = [:portfolio_index, :llm, :complete, :stop]
      synapse_event = [:synapse, :ai, :generate, :stop]

      assert Telemetry.synapse_event(portfolio_event) == synapse_event
    end

    test "converts portfolio_index embedder event to synapse event" do
      portfolio_event = [:portfolio_index, :embedder, :embed]
      synapse_event = [:synapse, :ai, :embed, :stop]

      assert Telemetry.synapse_event(portfolio_event) == synapse_event
    end

    test "falls back for unmapped portfolio_index events" do
      other_event = [:portfolio_index, :custom, :event]
      assert Telemetry.synapse_event(other_event) == [:synapse, :ai, :custom, :event]
    end

    test "returns non-portfolio events unchanged" do
      other_event = [:some, :other, :event]
      assert Telemetry.synapse_event(other_event) == other_event
    end
  end

  describe "handle_event/4" do
    test "forwards portfolio_index events to synapse namespace" do
      # Set up a test handler to capture forwarded events
      test_pid = self()

      handler_id = "test-synapse-ai-handler-#{:rand.uniform(1000)}"

      :telemetry.attach(
        handler_id,
        [:synapse, :ai, :test, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      # Trigger the handle_event function
      Telemetry.handle_event(
        [:portfolio_index, :test, :event],
        %{duration: 100},
        %{test: true},
        nil
      )

      # Should receive the forwarded event
      assert_receive {:telemetry_event, [:synapse, :ai, :test, :event], measurements, metadata},
                     1000

      assert measurements.duration == 100
      assert metadata.test == true
      assert metadata.source == :synapse_ai
      assert metadata.forwarded_from == [:portfolio_index, :test, :event]

      # Cleanup
      :telemetry.detach(handler_id)
    end
  end
end
