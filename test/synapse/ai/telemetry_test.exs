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
      assert [:altar, :ai, :generate, :start] in events
      assert [:altar, :ai, :generate, :stop] in events
      assert [:altar, :ai, :embed, :start] in events
    end
  end

  describe "synapse_event/1" do
    test "converts altar event to synapse event" do
      altar_event = [:altar, :ai, :generate, :stop]
      synapse_event = [:synapse, :ai, :generate, :stop]

      assert Telemetry.synapse_event(altar_event) == synapse_event
    end

    test "returns non-altar events unchanged" do
      other_event = [:some, :other, :event]
      assert Telemetry.synapse_event(other_event) == other_event
    end
  end

  describe "handle_event/4" do
    test "forwards altar events to synapse namespace" do
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
        [:altar, :ai, :test, :event],
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
      assert metadata.forwarded_from == [:altar, :ai, :test, :event]

      # Cleanup
      :telemetry.detach(handler_id)
    end
  end
end
