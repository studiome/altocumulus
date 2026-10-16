require "test_helper"

class SpecialSlotDayOverrideTest < ActiveSupport::TestCase
  DATE = Date.new(2026, 3, 3)

  def override(**attributes)
    SpecialSlotDayOverride.new({ resource: surgery_locations(:cath_lab), date: DATE, slot_count: 2 }.merge(attributes))
  end

  test "an override needs a resource, a date and a whole count of zero or more" do
    assert override.valid?
    assert override(slot_count: 0).valid?
    assert_not override(resource: nil).valid?
    assert_not override(date: nil).valid?
    assert_not override(slot_count: -1).valid?
    assert_not override(slot_count: 1.5).valid?
    assert_not override(slot_count: nil).valid?
    assert_not override(slot_count: "abc").valid?
  end

  test "a resource has one override per date; other dates and other resources are free" do
    override.save!
    assert_not override.valid?
    assert override(date: DATE + 1).valid?
    assert override(resource: surgical_devices(:robot_a)).valid?
  end

  test "devices and locations with the same id do not clash" do
    override(resource: surgery_locations(:cath_lab)).save!
    device = SurgicalDevice.create!(name: "Same Id Device", id: surgery_locations(:cath_lab).id)
    assert override(resource: device).valid?
  end

  test "only locations and devices can have overrides" do
    assert_not override(resource: departments(:gynecology)).valid?
  end

  test "a resource needs no weekly rule to have an override" do
    assert_empty surgery_locations(:cath_lab).special_slot_rules
    assert override.save
  end

  test "deleting a resource removes its overrides" do
    override.save!
    assert_difference "SpecialSlotDayOverride.count", -1 do
      surgery_locations(:cath_lab).destroy!
    end
  end
end
