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

  test "warnings uses plural agreement when several surgeries overrun" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 3),
      rule: elective_slot_rules(:tuesday),
      elective_surgeries: [ surgeries(:five), surgeries(:five) ],
      emergency_surgeries: []
    )

    assert_includes usage.warnings, "2 surgeries run past their 240 min slots."
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

  test "holiday? reflects whether a holiday falls on the date" do
    usages = ElectiveSlotUsage.for_dates([ Date.new(2026, 3, 3), holidays(:national_holiday).date ])

    assert_not usages[Date.new(2026, 3, 3)].holiday?
    assert usages[holidays(:national_holiday).date].holiday?
    assert_equal holidays(:national_holiday), usages[holidays(:national_holiday).date].holiday
  end

  test "a holiday zeroes out the day's elective slots even though a rule exists" do
    usage = ElectiveSlotUsage.for_dates([ holidays(:national_holiday).date ])[holidays(:national_holiday).date]

    assert usage.rule.present? # Tuesday has a configured rule
    assert_nil usage.effective_rule
    assert_equal 0, usage.slot_count
    assert_nil usage.slot_duration_minutes
    assert_not usage.configured?
    assert_empty usage.overrunning_surgeries
  end

  test "a holiday with elective surgeries warns and does not duplicate the unconfigured-day warning" do
    holiday = holidays(:national_holiday)
    surgery = Surgery.create!(
      patient: patients(:one),
      surgery_date: holiday.date,
      scheduling_type: "elective",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    usage = ElectiveSlotUsage.for_dates([ holiday.date ])[holiday.date]

    assert_includes usage.warnings, "#{holiday.name} is a holiday: no elective slots are available."
    assert_not usage.warnings.any? { |message| message.start_with?("No elective slots are configured for") }
    assert usage.over_capacity? # 1 elective surgery against 0 slots
  ensure
    surgery&.destroy
  end

  test "emergency surgeries are returned unaffected on a holiday" do
    holiday = holidays(:national_holiday)
    emergency_surgery = Surgery.create!(
      patient: patients(:one),
      surgery_date: holiday.date,
      scheduling_type: "emergency",
      start_time: "03:00",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    usage = ElectiveSlotUsage.for_dates([ holiday.date ])[holiday.date]

    assert_includes usage.emergency_surgeries, emergency_surgery
    assert_empty usage.warnings
  ensure
    emergency_surgery&.destroy
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
