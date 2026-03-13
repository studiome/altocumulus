require "test_helper"

class SurgeryTest < ActiveSupport::TestCase
  test "should be valid" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      procedure: "Appendectomy",
      anesthesia_method: "General",
      duration_minutes: 90
    )

    assert surgery.valid?
  end

  test "should require surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    assert_not surgery.valid?
  end

  test "should require procedure" do
    surgery = surgeries(:one)
    surgery.procedure = nil
    assert_not surgery.valid?
  end

  test "should require anesthesia_method" do
    surgery = surgeries(:one)
    surgery.anesthesia_method = nil
    assert_not surgery.valid?
  end

  test "duration_minutes should be non-negative integer" do
    surgery = surgeries(:one)
    surgery.duration_minutes = -1
    assert_not surgery.valid?
  end
end

