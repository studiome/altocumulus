require "test_helper"

class AdmissionThresholdRuleTest < ActiveSupport::TestCase
  test "is valid with a weekday and a threshold" do
    assert AdmissionThresholdRule.new(day_of_week: 1, threshold: 3).valid?
  end

  test "allows a threshold of zero" do
    assert AdmissionThresholdRule.new(day_of_week: 1, threshold: 0).valid?
  end

  test "requires a weekday between 0 and 6" do
    assert_not AdmissionThresholdRule.new(day_of_week: nil, threshold: 3).valid?
    assert_not AdmissionThresholdRule.new(day_of_week: 7, threshold: 3).valid?
    assert_not AdmissionThresholdRule.new(day_of_week: -1, threshold: 3).valid?
  end

  test "requires a whole, non-negative threshold" do
    assert_not AdmissionThresholdRule.new(day_of_week: 1, threshold: nil).valid?
    assert_not AdmissionThresholdRule.new(day_of_week: 1, threshold: -1).valid?
    assert_not AdmissionThresholdRule.new(day_of_week: 1, threshold: 2.5).valid?
  end

  test "allows one rule per weekday" do
    AdmissionThresholdRule.create!(day_of_week: 1, threshold: 3)
    duplicate = AdmissionThresholdRule.new(day_of_week: 1, threshold: 4)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:day_of_week, :taken)
  end
end
