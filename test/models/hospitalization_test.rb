require "test_helper"

class HospitalizationTest < ActiveSupport::TestCase
  test "should be valid" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      planned_days: 5,
      reason: "Fever",
      hospitalization_diagnoses_attributes: [
        { diagnosis_id: diagnoses(:pneumonia).id },
        { diagnosis_id: diagnoses(:hypertension).id }
      ]
    )

    assert hospitalization.valid?
  end

  test "should require admission_date" do
    hospitalization = hospitalizations(:one)
    hospitalization.admission_date = nil
    assert_not hospitalization.valid?
  end

  test "should require reason" do
    hospitalization = hospitalizations(:one)
    hospitalization.reason = nil
    assert_not hospitalization.valid?
  end

  test "planned_days should be a positive integer when present" do
    hospitalization = hospitalizations(:one)

    hospitalization.planned_days = 0
    assert_not hospitalization.valid?

    hospitalization.planned_days = -1
    assert_not hospitalization.valid?

    hospitalization.planned_days = nil
    assert hospitalization.valid?
  end

  test "should require at least one diagnosis" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      reason: "Fever"
    )

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:hospitalization_diagnoses], "must include at least one diagnosis"
  end

  test "should reject duplicate diagnoses" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [
        { diagnosis_id: diagnoses(:pneumonia).id },
        { diagnosis_id: diagnoses(:pneumonia).id }
      ]
    )

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:hospitalization_diagnoses], "must not include duplicate diagnoses"
  end

  test "diagnosis_names_display joins names" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [
        { diagnosis_id: diagnoses(:pneumonia).id },
        { diagnosis_id: diagnoses(:hypertension).id }
      ]
    )

    assert_equal "Pneumonia、Hypertension", hospitalization.diagnosis_names_display
  end

  test "diagnosis_names_display returns dash when no diagnoses" do
    hospitalization = Hospitalization.new(patient: patients(:one))

    assert_equal "-", hospitalization.diagnosis_names_display
  end
end
