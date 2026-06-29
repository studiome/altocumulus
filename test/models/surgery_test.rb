require "test_helper"

class SurgeryTest < ActiveSupport::TestCase
  test "should be valid" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert surgery.valid?
  end

  test "should require surgery_date" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    assert_not surgery.valid?
  end

  test "first procedure_names entry reflects first selection" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
      ]
    )

    assert surgery.valid?
    assert_equal "Cholecystectomy", surgery.procedure_names.first
  end

  test "should require at least one procedure selection" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must include at least one procedure"
  end

  test "should limit procedure selections to five" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" },
        { surgery_procedure_id: surgery_procedures(:cholecystectomy).id, laterality: "bilateral" },
        { surgery_procedure_id: surgery_procedures(:updated_procedure).id, laterality: "none" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must be five or fewer"
  end

  test "should reject duplicate procedure selections" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "left" }
      ]
    )

    assert_not surgery.valid?
    assert_includes surgery.errors[:surgery_procedure_selections], "must not include duplicate procedures"
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
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "none" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "left" }
      ]
    )

    assert_equal "Appendectomy、Left Knee arthroscopy", surgery.display_procedure_name
  end

  test "display_procedure_name should prefix laterality when present" do
    surgery = Surgery.new(
      patient: patients(:one),
      surgery_date: Date.new(2026, 3, 1),
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" },
        { surgery_procedure_id: surgery_procedures(:knee_arthroscopy).id, laterality: "bilateral" }
      ]
    )

    assert_equal "Right Appendectomy、Bilateral Knee arthroscopy", surgery.display_procedure_name
  end
end
