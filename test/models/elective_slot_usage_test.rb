require "test_helper"

class ElectiveSlotUsageTest < ActiveSupport::TestCase
  test "for_dates returns a usage per date" do
    dates = [ Date.new(2026, 3, 1), Date.new(2026, 3, 3) ]
    usages = ElectiveSlotUsage.for_dates(dates)

    assert_equal dates, usages.keys
    assert_instance_of ElectiveSlotUsage, usages[Date.new(2026, 3, 1)]
  end

  test "configured? reflects whether a slot rule exists for the date" do
    usages = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 1), Date.new(2026, 3, 3) ])

    assert_not usages[Date.new(2026, 3, 1)].configured? # Sunday, no rule
    assert usages[Date.new(2026, 3, 3)].configured?     # Tuesday, has a rule
  end

  test "separates elective and emergency surgeries for the same date" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 1) ])[Date.new(2026, 3, 1)]

    assert_includes usage.elective_surgeries, surgeries(:one)
    assert_includes usage.emergency_surgeries, surgeries(:emergency_one)
    assert_not_includes usage.elective_surgeries, surgeries(:emergency_one)
    assert_not_includes usage.emergency_surgeries, surgeries(:one)
  end

  test "slot_count and slot_duration_minutes fall back sensibly when unconfigured" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 1) ])[Date.new(2026, 3, 1)]

    assert_equal 0, usage.slot_count
    assert_nil usage.slot_duration_minutes
  end

  test "used_slots, remaining_slots, over_capacity? and over_capacity_count on a Tuesday with 4 elective surgeries in 3 slots" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 3) ])[Date.new(2026, 3, 3)]

    assert_equal 4, usage.used_slots
    assert_equal 0, usage.remaining_slots
    assert usage.over_capacity?
    assert_equal 1, usage.over_capacity_count
  end

  test "remaining_slots and over_capacity? on a day within capacity" do
    # Build a usage for a day with room to spare using the wednesday rule
    # directly, since none of the fixtures populate it.
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday),
      elective_surgeries: [],
      emergency_surgeries: []
    )

    assert_equal 0, usage.used_slots
    assert_equal 2, usage.remaining_slots
    assert_not usage.over_capacity?
    assert_equal 0, usage.over_capacity_count
  end

  test "overrunning_surgeries lists only elective surgeries that exceed the slot duration" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 3) ])[Date.new(2026, 3, 3)]

    assert_equal [ surgeries(:five) ], usage.overrunning_surgeries
  end

  test "overrunning_surgeries is empty when unconfigured" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 1) ])[Date.new(2026, 3, 1)]

    assert_empty usage.overrunning_surgeries
  end

  test "warnings flags an unconfigured weekday with elective surgeries" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 1) ])[Date.new(2026, 3, 1)]

    assert_includes usage.warnings, "No elective slots are configured for Sunday."
  end

  test "warnings does not flag an unconfigured weekday with only emergency surgeries" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 1),
      rule: nil,
      elective_surgeries: [],
      emergency_surgeries: [ surgeries(:emergency_one) ]
    )

    assert_empty usage.warnings
  end

  test "warnings flags over capacity and slot overruns on the configured Tuesday" do
    usage = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 3) ])[Date.new(2026, 3, 3)]

    assert_includes usage.warnings, "Over capacity: 4 elective surgeries in 3 slots."
    assert_includes usage.warnings, "1 surgery runs past its 240 min slot."
  end

  test "warnings is empty for a fully within-capacity, non-overrunning day" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday),
      elective_surgeries: [],
      emergency_surgeries: []
    )

    assert_empty usage.warnings
  end

  test "for_dates does not issue more queries as the number of dates grows" do
    one_date_queries = count_queries { ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 3) ]) }
    full_week_queries = count_queries { ElectiveSlotUsage.for_dates((Date.new(2026, 3, 1)..Date.new(2026, 3, 7)).to_a) }

    assert_equal one_date_queries, full_week_queries
  end

  private

    def count_queries
      count = 0
      counter = ->(*) { count += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
