require "test_helper"

class SpecialSlotRuleTest < ActiveSupport::TestCase
  setup { @location = surgery_locations(:cath_lab) }

  def rule(**attributes)
    SpecialSlotRule.new({ resource: @location, day_of_week: 1, slot_count: 2 }.merge(attributes))
  end

  test "a rule needs a resource, a weekday from 0 to 6 and a whole count of zero or more" do
    assert rule.valid?
    assert rule(slot_count: 0).valid?
    assert_not rule(resource: nil).valid?
    assert_not rule(day_of_week: 7).valid?
    assert_not rule(day_of_week: -1).valid?
    assert_not rule(slot_count: -1).valid?
    assert_not rule(slot_count: 1.5).valid?
    assert_not rule(slot_count: nil).valid?
  end

  test "a resource has at most one rule per weekday, and the same weekday can belong to another resource" do
    rule.save!
    assert_not rule.valid?
    assert rule(day_of_week: 2).valid?
    assert rule(resource: surgical_devices(:robot_a)).valid?
  end

  test "devices and locations with the same id do not clash" do
    SpecialSlotRule.create!(resource: surgery_locations(:cath_lab), day_of_week: 1, slot_count: 1)
    device = SurgicalDevice.create!(name: "Same Id Device", id: surgery_locations(:cath_lab).id)
    assert SpecialSlotRule.new(resource: device, day_of_week: 1, slot_count: 1).valid?
  end
end
