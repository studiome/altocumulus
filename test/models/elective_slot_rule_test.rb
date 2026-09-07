require "test_helper"

class ElectiveSlotRuleTest < ActiveSupport::TestCase
  test "should be valid" do
    rule = ElectiveSlotRule.new(day_of_week: 4, slot_count: 2, slot_duration_minutes: 120)
    assert rule.valid?
  end

  test "should require day_of_week" do
    rule = elective_slot_rules(:tuesday)
    rule.day_of_week = nil
    assert_not rule.valid?
  end

  test "should require day_of_week to be within 0..6" do
    rule = ElectiveSlotRule.new(day_of_week: 7, slot_count: 1, slot_duration_minutes: 60)
    assert_not rule.valid?
    assert_includes rule.errors[:day_of_week], "is not included in the list"
  end

  test "should require day_of_week to be unique" do
    rule = ElectiveSlotRule.new(day_of_week: elective_slot_rules(:tuesday).day_of_week, slot_count: 1, slot_duration_minutes: 60)
    assert_not rule.valid?
    assert_includes rule.errors[:day_of_week], "has already been taken"
  end

  test "slot_count must be greater than zero" do
    rule = elective_slot_rules(:tuesday)

    rule.slot_count = 0
    assert_not rule.valid?

    rule.slot_count = -1
    assert_not rule.valid?
  end

  # A fractional slot_count means the day's last slot is shorter than the
  # rest, e.g. 2.5 slots x 240 min = two full 240 min slots plus one 120 min
  # slot. This is how the legacy "2.5 rooms" schedules are represented
  # without hardcoding weekday-specific values anywhere.
  test "slot_count accepts fractional values representing a short last slot" do
    rule = elective_slot_rules(:tuesday)
    rule.slot_count = 2.5
    assert rule.valid?
  end

  test "slot_duration_minutes must be a positive integer" do
    rule = elective_slot_rules(:tuesday)

    rule.slot_duration_minutes = 0
    assert_not rule.valid?

    rule.slot_duration_minutes = -1
    assert_not rule.valid?
  end

  test "ordered scope sorts by day_of_week" do
    assert_equal [ 2, 3, 5 ], ElectiveSlotRule.ordered.pluck(:day_of_week)
  end

  test "by_day_of_week indexes rules by their day_of_week" do
    indexed = ElectiveSlotRule.by_day_of_week
    assert_equal elective_slot_rules(:tuesday), indexed[2]
    assert_equal elective_slot_rules(:wednesday), indexed[3]
    assert_equal elective_slot_rules(:friday), indexed[5]
    assert_nil indexed[0]
  end

  test "day_of_week_form_options lists all seven days in order" do
    options = ElectiveSlotRule.day_of_week_form_options
    assert_equal [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ], options.map(&:first)
    assert_equal (0..6).to_a, options.map(&:last)
  end

  test "day_name returns the weekday name" do
    assert_equal "Tuesday", elective_slot_rules(:tuesday).day_name
  end

  test "slot_duration_hours rounds to one decimal place" do
    rule = elective_slot_rules(:tuesday)
    assert_equal 4.0, rule.slot_duration_hours

    rule.slot_duration_minutes = 100
    assert_equal 1.7, rule.slot_duration_hours
  end

  test "total_minutes multiplies slot_count by slot_duration_minutes" do
    assert_equal 720, elective_slot_rules(:tuesday).total_minutes
  end

  test "total_minutes keeps the fractional slot_count uncollapsed" do
    rule = ElectiveSlotRule.new(day_of_week: 0, slot_count: 2.5, slot_duration_minutes: 240)
    assert_equal 600, rule.total_minutes
  end

  test "total_slots rounds a fractional slot_count up to the whole number of slots" do
    assert_equal 3, elective_slot_rules(:tuesday).total_slots

    rule = ElectiveSlotRule.new(day_of_week: 0, slot_count: 2.5, slot_duration_minutes: 240)
    assert_equal 3, rule.total_slots
  end

  test "total_slots for a whole slot_count equals slot_count itself" do
    rule = ElectiveSlotRule.new(day_of_week: 0, slot_count: 3, slot_duration_minutes: 240)
    assert_equal 3, rule.total_slots
  end

  # The heart of decision #3: the fractional remainder means the last slot of
  # the day is shorter, not that there is a whole extra slot.
  test "slot_durations gives every slot's own length, with only the last one shortened" do
    rule = ElectiveSlotRule.new(day_of_week: 0, slot_count: 2.5, slot_duration_minutes: 240)
    assert_equal [ 240, 240, 120 ], rule.slot_durations
  end

  test "slot_durations for a whole slot_count is uniform" do
    assert_equal [ 240, 240, 240 ], elective_slot_rules(:tuesday).slot_durations
  end

  test "slot_count_display shows a whole slot_count without a trailing .0" do
    assert_equal "3", elective_slot_rules(:tuesday).slot_count_display
  end

  test "slot_count_display shows a fractional slot_count as entered" do
    rule = ElectiveSlotRule.new(day_of_week: 0, slot_count: 2.5, slot_duration_minutes: 240)
    assert_equal "2.5", rule.slot_count_display
  end

  test "to_s summarizes the rule" do
    assert_equal "Tuesday - 3 slots x 240 min", elective_slot_rules(:tuesday).to_s
  end

  test "to_s shows a fractional slot_count without a trailing .0 artifact" do
    rule = ElectiveSlotRule.new(day_of_week: 1, slot_count: 2.5, slot_duration_minutes: 240)
    assert_equal "Monday - 2.5 slots x 240 min", rule.to_s
  end
end
