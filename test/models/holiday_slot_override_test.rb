require "test_helper"

# A comment-only Holiday row (holiday: false) can override the weekday's slot
# rule for its date; a closed day cannot carry an override.
class HolidaySlotOverrideTest < ActiveSupport::TestCase
  TUESDAY = Date.new(2026, 3, 3)    # rule: 3 slots x 240 min
  SUNDAY = Date.new(2026, 3, 1)     # no rule
  OTHER_TUESDAY = Date.new(2026, 3, 17)

  def note_day(date, **attrs)
    Holiday.new(date: date, holiday: false, note: "Reduced staffing", **attrs)
  end

  def usage_for(date)
    ElectiveSlotUsage.for_dates([ date ])[date]
  end

  test "override fields are optional" do
    assert note_day(OTHER_TUESDAY).valid?
    assert_not note_day(OTHER_TUESDAY).slot_override?
  end

  test "a closed day cannot carry an override" do
    holiday = Holiday.new(date: OTHER_TUESDAY, holiday: true, name: "Closed", slot_count: 2)
    assert_not holiday.valid?
    assert holiday.errors.key?(:slot_count)

    holiday = Holiday.new(date: OTHER_TUESDAY, holiday: true, name: "Closed", slot_duration_minutes: 120)
    assert_not holiday.valid?
    assert holiday.errors.key?(:slot_duration_minutes)
  end

  test "slot_count and duration must be positive, duration a whole number" do
    assert_not note_day(OTHER_TUESDAY, slot_count: 0).valid?
    assert_not note_day(OTHER_TUESDAY, slot_count: -1).valid?
    assert_not note_day(OTHER_TUESDAY, slot_count: 2, slot_duration_minutes: 0).valid?
    assert_not note_day(OTHER_TUESDAY, slot_count: 2, slot_duration_minutes: 90.5).valid?
    assert note_day(OTHER_TUESDAY, slot_count: 2.5, slot_duration_minutes: 90).valid?
  end

  test "a duration without a slot count is rejected" do
    holiday = note_day(OTHER_TUESDAY, slot_duration_minutes: 120)
    assert_not holiday.valid?
    assert holiday.errors.key?(:slot_count)
  end

  test "the duration is required when the weekday has no slot rule" do
    holiday = note_day(SUNDAY + 7, slot_count: 2)
    assert_not holiday.valid?
    assert holiday.errors.of_kind?(:slot_duration_minutes, :required_without_weekday_rule)
    assert_includes holiday.errors.full_messages.join, "weekday has no slot rule"

    holiday.slot_duration_minutes = 120
    assert holiday.valid?
  end

  test "the duration may be left blank when the weekday has a rule" do
    assert note_day(OTHER_TUESDAY, slot_count: 2).valid?
  end

  test "the weekday rule drives the usage without an override" do
    usage = usage_for(TUESDAY)
    assert_equal 3, usage.total_slots
    assert_not usage.slot_override?
  end

  test "an override replaces the slot count and keeps the weekday duration" do
    note_day(OTHER_TUESDAY, slot_count: 2).save!
    usage = usage_for(OTHER_TUESDAY)

    assert usage.configured?
    assert usage.slot_override?
    assert_equal 2, usage.total_slots
    assert_equal 240, usage.slot_duration_minutes
    assert_equal 480, usage.capacity_minutes
    assert_equal [ 240, 240 ], usage.slots.map(&:duration_minutes)
  end

  test "an override may change the duration too" do
    note_day(OTHER_TUESDAY, slot_count: 4, slot_duration_minutes: 120).save!
    usage = usage_for(OTHER_TUESDAY)

    assert_equal 4, usage.total_slots
    assert_equal 120, usage.slot_duration_minutes
    assert_equal 480, usage.capacity_minutes
  end

  test "an override can open slots on a weekday with no rule" do
    date = SUNDAY + 7
    note_day(date, slot_count: 1, slot_duration_minutes: 180).save!
    usage = usage_for(date)

    assert usage.configured?
    assert_equal 1, usage.total_slots
    assert_equal 180, usage.capacity_minutes
  end

  test "a fractional override keeps the shorter last slot" do
    note_day(OTHER_TUESDAY, slot_count: 2.5, slot_duration_minutes: 120).save!
    usage = usage_for(OTHER_TUESDAY)

    assert_equal 3, usage.total_slots
    assert_equal [ 120, 120, 60 ], usage.slots.map(&:duration_minutes)
    assert_equal 300, usage.capacity_minutes
  end

  test "surgeries beyond an overridden slot count are unscheduled" do
    surgery = Surgery.create!(
      patient: patients(:one), surgery_date: OTHER_TUESDAY, slot_number: 3, anesthesia_method: "General",
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )
    assert_equal 0, usage_for(OTHER_TUESDAY).over_capacity_count

    note_day(OTHER_TUESDAY, slot_count: 2).save!
    usage = usage_for(OTHER_TUESDAY)
    assert usage.over_capacity?
    assert_equal [ surgery ], usage.unscheduled_surgeries
  end

  test "a closed day ignores any override" do
    holiday = Holiday.new(date: OTHER_TUESDAY, holiday: true, name: "Closed")
    holiday.save!
    holiday.update_columns(slot_count: 2)
    usage = usage_for(OTHER_TUESDAY)

    assert_not usage.configured?
    assert_not usage.slot_override?
  end

  test "an unrelated note-only day still uses the weekday rule" do
    Holiday.create!(date: OTHER_TUESDAY, holiday: false, note: "Just a note")
    usage = usage_for(OTHER_TUESDAY)
    assert_equal 3, usage.total_slots
    assert_not usage.slot_override?
  end

  test "overrides add no queries as the number of dates grows" do
    note_day(OTHER_TUESDAY, slot_count: 2).save!
    count = lambda do |dates|
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveRecord::Base.uncached { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { ElectiveSlotUsage.for_dates(dates) } }
      queries
    end
    assert_equal count.call([ TUESDAY ]), count.call((SUNDAY..(SUNDAY + 20)).to_a)
  end
end
