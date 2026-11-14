require "test_helper"

class LiveUpdateTest < ActiveSupport::TestCase
  test "broadcasts the dates and records on the global stream" do
    updates = live_updates do
      LiveUpdate.broadcast(dates: [ Date.new(2026, 11, 14), "2026-11-15" ], records: %w[Surgery:12 Patient:3])
    end

    assert_equal 1, updates.size
    assert_equal %w[2026-11-14 2026-11-15], updates.first[:dates]
    assert_equal %w[Surgery:12 Patient:3], updates.first[:records]
    assert_not updates.first[:all]
  end

  test "drops nils and duplicates" do
    updates = live_updates do
      LiveUpdate.broadcast(dates: [ nil, Date.new(2026, 11, 14), Date.new(2026, 11, 14) ], records: [ "Patient:3", nil, "Patient:3" ])
    end

    assert_equal [ "2026-11-14" ], updates.first[:dates]
    assert_equal [ "Patient:3" ], updates.first[:records]
  end

  test "all sends the all flag" do
    updates = live_updates { LiveUpdate.broadcast(all: true) }

    assert updates.first[:all]
  end

  test "sends nothing when there is nothing to say" do
    assert_no_turbo_stream_broadcasts(LiveUpdate::STREAM) do
      LiveUpdate.broadcast
      LiveUpdate.broadcast(dates: [ nil ], records: [])
    end
  end

  test "the payload carries only dates and Model:id keys" do
    LiveUpdate.broadcast(dates: [ Date.new(2026, 11, 14) ], records: [ "Patient:3" ])

    html = ActiveSupport::JSON.decode(broadcasts(LiveUpdate::STREAM).last)
    assert_equal %(<turbo-stream action="live_update" dates="2026-11-14" records="Patient:3"></turbo-stream>), html
  end

  test "a failing broadcast is logged and never raised" do
    original = Turbo::StreamsChannel.method(:broadcast_stream_to)
    Turbo::StreamsChannel.define_singleton_method(:broadcast_stream_to) { |*, **| raise "cable down" }
    begin
      assert_nothing_raised { LiveUpdate.broadcast(all: true) }
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_stream_to, original)
    end
  end
end
