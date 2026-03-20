require "test_helper"

class SurgeryTest < ActiveSupport::TestCase
  test "should be valid" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      laterality: "right",
      procedure: surgery_procedures(:appendectomy).name,
      anesthesia_method: "General",
      duration_hours: 1.5
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

  test "should require procedure to exist in the master list" do
    surgery = surgeries(:one)
    surgery.procedure = "Not in list"

    assert_not surgery.valid?
  end

  test "should require anesthesia_method" do
    surgery = surgeries(:one)
    surgery.anesthesia_method = nil
    assert_not surgery.valid?
  end

  test "duration_hours should be non-negative" do
    surgery = surgeries(:one)
    surgery.duration_hours = -1.0
    assert_not surgery.valid?
  end

  test "display_procedure_name should omit laterality when none" do
    surgery = surgeries(:one)
    surgery.laterality = "none"

    assert_equal surgery.procedure, surgery.display_procedure_name
  end

  test "display_procedure_name should prefix laterality when present" do
    surgery = surgeries(:one)
    surgery.laterality = "left"

    assert_equal "Left #{surgery.procedure}", surgery.display_procedure_name
  end
end
