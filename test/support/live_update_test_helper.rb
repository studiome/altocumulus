# Reads the signal LiveUpdate broadcasts, for model and controller tests.
require "turbo/broadcastable/test_helper"

module LiveUpdateTestHelper
  extend ActiveSupport::Concern

  # Included explicitly: turbo-rails only adds it once ActionCable is loaded,
  # which depends on what ran before.
  included do
    include Turbo::Broadcastable::TestHelper
  end

  # The decoded signals broadcast while the block runs:
  # [{ dates: [...], records: [...], all: bool }, ...]
  def live_updates(&block)
    elements = capture_turbo_stream_broadcasts(LiveUpdate::STREAM, &block)
    elements.map do |element|
      assert_equal "live_update", element["action"]
      { dates: element["dates"].to_s.split, records: element["records"].to_s.split, all: element["all"] == "true" }
    end
  end

  def live_dates(&block)
    live_updates(&block).flat_map { |update| update[:dates] }.uniq
  end

  def live_records(&block)
    live_updates(&block).flat_map { |update| update[:records] }.uniq
  end
end
