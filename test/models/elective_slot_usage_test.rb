require "test_helper"

class ElectiveSlotUsageTest < ActiveSupport::TestCase
  TUESDAY = Date.new(2026, 3, 3)   # 3 slots x 240 min
  SUNDAY  = Date.new(2026, 3, 1)   # no rule configured

  test "for_dates returns a usage per date" do
    dates = [ SUNDAY, TUESDAY ]
    usages = ElectiveSlotUsage.for_dates(dates)

    assert_equal dates, usages.keys
    assert_instance_of ElectiveSlotUsage, usages[SUNDAY]
  end

  test "configured? reflects whether a slot rule exists for the date" do
    usages = ElectiveSlotUsage.for_dates([ SUNDAY, TUESDAY ])

    assert_not usages[SUNDAY].configured?
    assert usages[TUESDAY].configured?
  end

  test "separates elective and emergency surgeries for the same date" do
    usage = ElectiveSlotUsage.for_dates([ SUNDAY ])[SUNDAY]

    assert_includes usage.elective_surgeries, surgeries(:one)
    assert_includes usage.emergency_surgeries, surgeries(:emergency_one)
    assert_not_includes usage.elective_surgeries, surgeries(:emergency_one)
    assert_not_includes usage.emergency_surgeries, surgeries(:one)
  end

  test "slot_count and slot_duration_minutes fall back sensibly when unconfigured" do
    usage = ElectiveSlotUsage.for_dates([ SUNDAY ])[SUNDAY]

    assert_equal 0, usage.slot_count
    assert_nil usage.slot_duration_minutes
    assert_empty usage.slots
  end

  # The central rule: a slot is a whole day of one operating room, so it holds
  # however many surgeries fit in its duration - not exactly one.
  test "slots gather every surgery assigned to them" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal 3, usage.slots.size
    assert_equal [ 1, 2, 3 ], usage.slots.map(&:number)
    assert_equal [ surgeries(:three), surgeries(:four) ], usage.slots.first.surgeries
    assert_equal [ surgeries(:five) ], usage.slots.second.surgeries
    assert_empty usage.slots.third.surgeries
  end

  test "a slot sums the durations of the surgeries booked into it" do
    slot = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY].slots.first

    assert_equal 120, slot.used_minutes
    assert_equal 120, slot.remaining_minutes
    assert_not slot.overrun?
    assert_nil slot.overrun_minutes
    assert_not slot.empty?
  end

  test "two surgeries sharing one slot are within capacity" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal 2, usage.slots.first.surgeries.size
    assert_not usage.slots.first.overrun?
    assert_not_includes usage.overrunning_slots, usage.slots.first
  end

  test "a slot overruns only when the surgeries in it exceed the slot duration" do
    slot = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY].slots.second

    assert_equal 300, slot.used_minutes
    assert_equal 0, slot.remaining_minutes
    assert slot.overrun?
    assert_equal 60, slot.overrun_minutes
  end

  test "an empty slot reports itself as empty" do
    slot = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY].slots.third

    assert slot.empty?
    assert_equal 0, slot.used_minutes
    assert_equal 240, slot.remaining_minutes
    assert_not slot.overrun?
  end

  test "used_slots counts slots holding at least one surgery, not surgeries" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal 2, usage.used_slots
    assert_equal 1, usage.remaining_slots
  end

  test "used_minutes and capacity_minutes report the day's booked time" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal 420, usage.used_minutes    # 60 + 60 + 300
    assert_equal 720, usage.capacity_minutes # 3 slots x 240 min
  end

  test "surgeries with no slot number are unscheduled rather than filling a slot" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal [ surgeries(:six) ], usage.unscheduled_surgeries
    assert usage.over_capacity?
    usage.slots.each { |slot| assert_not_includes slot.surgeries, surgeries(:six) }
  end

  test "a surgery pointing at a slot beyond the day's slot count is unscheduled" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday), # 2 slots x 180 min
      elective_surgeries: [ surgeries(:three), out_of_range_surgery ],
      emergency_surgeries: []
    )

    assert_equal [ out_of_range_surgery ], usage.unscheduled_surgeries
    assert usage.over_capacity?
  end

  test "overrunning_slots lists only the slots that exceed the slot duration" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_equal [ 2 ], usage.overrunning_slots.map(&:number)
  end

  test "overrunning_slots is empty when unconfigured" do
    usage = ElectiveSlotUsage.for_dates([ SUNDAY ])[SUNDAY]

    assert_empty usage.overrunning_slots
  end

  test "surgeries with no recorded duration do not count towards a slot's minutes" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday),
      elective_surgeries: [ durationless_surgery ],
      emergency_surgeries: []
    )

    assert_equal [ durationless_surgery ], usage.slots.first.surgeries
    assert_equal 0, usage.slots.first.used_minutes
    assert_not usage.slots.first.overrun?
  end

  test "warnings flags an unconfigured weekday with elective surgeries" do
    usage = ElectiveSlotUsage.for_dates([ SUNDAY ])[SUNDAY]

    assert_includes usage.warnings, "No elective slots are configured for Sunday."
  end

  test "warnings does not flag an unconfigured weekday with only emergency surgeries" do
    usage = ElectiveSlotUsage.new(
      date: SUNDAY,
      rule: nil,
      elective_surgeries: [],
      emergency_surgeries: [ surgeries(:emergency_one) ]
    )

    assert_empty usage.warnings
  end

  test "warnings reports unscheduled surgeries and slot overruns on the configured Tuesday" do
    usage = ElectiveSlotUsage.for_dates([ TUESDAY ])[TUESDAY]

    assert_includes usage.warnings, "1 elective surgery is not assigned to an available slot."
    assert_includes usage.warnings, "Slot 2 is booked 60 min past its 240 min limit."
  end

  test "warnings uses plural agreement for several unscheduled surgeries" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday),
      elective_surgeries: [ surgeries(:six), out_of_range_surgery ],
      emergency_surgeries: []
    )

    assert_includes usage.warnings, "2 elective surgeries are not assigned to an available slot."
  end

  test "warnings uses plural agreement when several slots overrun" do
    usage = ElectiveSlotUsage.new(
      date: TUESDAY,
      rule: elective_slot_rules(:tuesday),
      elective_surgeries: [ surgeries(:five), slot_two_long_surgery ],
      emergency_surgeries: []
    )

    assert_includes usage.warnings, "Slots 1, 2 are booked past their 240 min limit."
  end

  test "warnings on an unconfigured weekday does not also report unscheduled surgeries" do
    usage = ElectiveSlotUsage.for_dates([ SUNDAY ])[SUNDAY]

    assert_equal [ "No elective slots are configured for Sunday." ],
                 usage.warnings,
                 "the unconfigured message already explains why nothing can be scheduled"
  end

  test "warnings on a holiday says only that the day is a holiday" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 10),
      rule: elective_slot_rules(:tuesday),
      elective_surgeries: [ surgeries(:three) ],
      emergency_surgeries: [],
      holiday: holidays(:national_holiday)
    )

    assert_equal [ "#{holidays(:national_holiday).name} is a holiday: no elective slots are available." ],
                 usage.warnings,
                 "the holiday message already explains the missing slots"
  end

  test "warnings is empty for a fully within-capacity, non-overrunning day" do
    usage = ElectiveSlotUsage.new(
      date: Date.new(2026, 3, 4),
      rule: elective_slot_rules(:wednesday),
      elective_surgeries: [ surgeries(:three) ],
      emergency_surgeries: []
    )

    assert_empty usage.warnings
  end

  test "holiday? reflects whether a holiday falls on the date" do
    usages = ElectiveSlotUsage.for_dates([ TUESDAY, holidays(:national_holiday).date ])

    assert_not usages[TUESDAY].holiday?
    assert usages[holidays(:national_holiday).date].holiday?
    assert_equal holidays(:national_holiday), usages[holidays(:national_holiday).date].holiday
  end

  test "a holiday zeroes out the day's elective slots even though a rule exists" do
    usage = ElectiveSlotUsage.for_dates([ holidays(:national_holiday).date ])[holidays(:national_holiday).date]

    assert usage.rule.present?
    assert_nil usage.effective_rule
    assert_equal 0, usage.slot_count
    assert_nil usage.slot_duration_minutes
    assert_not usage.configured?
    assert_empty usage.slots
    assert_empty usage.overrunning_slots
  end

  test "a holiday with elective surgeries warns and does not duplicate the unconfigured-day warning" do
    holiday = holidays(:national_holiday)
    surgery = create_elective_surgery(date: holiday.date, slot_number: 1)

    usage = ElectiveSlotUsage.for_dates([ holiday.date ])[holiday.date]

    assert_includes usage.warnings, "#{holiday.name} is a holiday: no elective slots are available."
    assert_not usage.warnings.any? { |message| message.start_with?("No elective slots are configured for") }
    assert_equal [ surgery ], usage.unscheduled_surgeries
    assert usage.over_capacity?
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
    one_date_queries = count_queries { ElectiveSlotUsage.for_dates([ TUESDAY ]) }
    full_week_queries = count_queries { ElectiveSlotUsage.for_dates((SUNDAY..(SUNDAY + 6)).to_a) }

    assert_equal one_date_queries, full_week_queries
  end

  private

    def out_of_range_surgery
      @out_of_range_surgery ||= Surgery.new(scheduling_type: "elective", slot_number: 9, duration_hours: 1.0)
    end

    def durationless_surgery
      @durationless_surgery ||= Surgery.new(scheduling_type: "elective", slot_number: 1, duration_hours: nil)
    end

    def slot_two_long_surgery
      @slot_two_long_surgery ||= Surgery.new(scheduling_type: "elective", slot_number: 1, duration_hours: 5.0)
    end

    def create_elective_surgery(date:, slot_number:)
      Surgery.create!(
        patient: patients(:one),
        surgery_date: date,
        scheduling_type: "elective",
        slot_number: slot_number,
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
      )
    end

    def count_queries
      count = 0
      counter = ->(*) { count += 1 }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
