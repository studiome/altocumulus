require "test_helper"

class AdmissionThresholdTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 11, 9)
  TUESDAY = Date.new(2026, 11, 10)

  setup do
    @default = Rails.application.config.x.admission_warning_threshold
  end

  test "a weekday without a rule uses the default" do
    resolver = AdmissionThreshold.for_dates([ MONDAY ])
    assert_equal @default, resolver.threshold_for(MONDAY)
    assert_not resolver.overridden?(MONDAY)
  end

  test "the weekday rule beats the default" do
    AdmissionThresholdRule.create!(day_of_week: MONDAY.wday, threshold: 2)
    resolver = AdmissionThreshold.for_dates([ MONDAY, TUESDAY ])
    assert_equal 2, resolver.threshold_for(MONDAY)
    assert_equal @default, resolver.threshold_for(TUESDAY)
    assert_not resolver.overridden?(MONDAY)
  end

  test "a zero weekday rule is honoured" do
    AdmissionThresholdRule.create!(day_of_week: MONDAY.wday, threshold: 0)
    assert_equal 0, AdmissionThreshold.for_dates([ MONDAY ]).threshold_for(MONDAY)
  end

  test "the date override beats the weekday rule and is marked overridden" do
    AdmissionThresholdRule.create!(day_of_week: MONDAY.wday, threshold: 2)
    Holiday.create!(date: MONDAY, holiday: false, admission_threshold: 9)
    resolver = AdmissionThreshold.for_dates([ MONDAY, TUESDAY ])
    assert_equal 9, resolver.threshold_for(MONDAY)
    assert resolver.overridden?(MONDAY)
    assert_not resolver.overridden?(TUESDAY)
  end

  test "a closed day can carry an override, and zero overrides" do
    Holiday.create!(date: MONDAY, holiday: true, name: "Closed", admission_threshold: 0)
    resolver = AdmissionThreshold.for_dates([ MONDAY ])
    assert_equal 0, resolver.threshold_for(MONDAY)
    assert resolver.overridden?(MONDAY)
  end

  test "a holiday without an override falls through" do
    Holiday.create!(date: MONDAY, holiday: true, name: "Closed")
    resolver = AdmissionThreshold.for_dates([ MONDAY ])
    assert_equal @default, resolver.threshold_for(MONDAY)
    assert_not resolver.overridden?(MONDAY)
  end

  test "already loaded holidays are reused" do
    holidays = { MONDAY => Holiday.new(date: MONDAY, holiday: false, admission_threshold: 7) }
    assert_equal 7, AdmissionThreshold.for_dates([ MONDAY ], holidays: holidays).threshold_for(MONDAY)
  end

  test "the query count does not depend on the number of dates" do
    few = count_queries { AdmissionThreshold.for_dates([ MONDAY ]) }
    many = count_queries { AdmissionThreshold.for_dates((MONDAY..(MONDAY + 29)).to_a) }
    assert_equal few, many
  end

  private

    def count_queries
      count = 0
      counter = ->(_n, _s, _f, _i, payload) { count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" }
      ActiveRecord::Base.lease_connection.materialize_transactions
      ActiveRecord::Base.uncached { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield } }
      count
    end
end
