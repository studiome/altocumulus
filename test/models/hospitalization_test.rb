require "test_helper"

class HospitalizationTest < ActiveSupport::TestCase
  test "should be valid" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      discharge_date: Date.new(2026, 4, 6),
      outcome: "recovered",
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

  test "outcome must be one of the allowed options" do
    hospitalization = hospitalizations(:one)
    hospitalization.outcome = "not_a_real_outcome"
    assert_not hospitalization.valid?

    hospitalization.outcome = "recovered"
    assert hospitalization.valid?
  end

  test "discharge_destination must be one of the allowed options" do
    hospitalization = hospitalizations(:one)
    hospitalization.discharge_destination = "not_a_real_destination"
    assert_not hospitalization.valid?

    hospitalization.discharge_destination = "home"
    assert hospitalization.valid?
  end

  test "discharge_date must be on or after admission_date" do
    hospitalization = hospitalizations(:one)
    hospitalization.discharge_date = hospitalization.admission_date - 1

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:discharge_date], "must be on or after the admission date"
  end

  test "outcome is required when discharge_date is present" do
    hospitalization = hospitalizations(:one)
    hospitalization.outcome = nil

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:outcome], "can't be blank"
  end

  test "outcome and discharge_destination must be blank when discharge_date is absent" do
    hospitalization = hospitalizations(:three)
    hospitalization.outcome = "recovered"

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:outcome], "can only be set together with a discharge date"

    hospitalization.outcome = nil
    hospitalization.discharge_destination = "home"

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:discharge_destination], "can only be set together with a discharge date"
  end

  test "rejects overlapping hospitalization periods for the same patient" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 3, 3),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:admission_date], "overlaps another hospitalization for this patient"
  end

  test "rejects an open-ended hospitalization that overlaps an existing one" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 5, 1),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:admission_date], "overlaps another hospitalization for this patient"
  end

  test "allows non-overlapping hospitalization periods for the same patient" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      admission_date: Date.new(2026, 4, 1),
      discharge_date: Date.new(2026, 4, 5),
      outcome: "recovered",
      reason: "Fever",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert hospitalization.valid?
  end

  test "allows saving the same hospitalization record without triggering an overlap with itself" do
    hospitalization = hospitalizations(:one)
    hospitalization.room_preference = "Updated room"

    assert hospitalization.valid?
  end

  test "discharged? and in_hospital?" do
    assert hospitalizations(:one).discharged?
    assert_not hospitalizations(:one).in_hospital?

    assert hospitalizations(:three).in_hospital?
    assert_not hospitalizations(:three).discharged?
  end

  test "length_of_stay counts both admission and discharge day, nil while in hospital" do
    hospitalization = hospitalizations(:one)
    assert_equal 6, hospitalization.length_of_stay

    assert_nil hospitalizations(:three).length_of_stay
  end

  test "days_since_admission is nil once discharged" do
    travel_to Date.new(2026, 6, 4) do
      assert_equal 4, hospitalizations(:three).days_since_admission
      assert_nil hospitalizations(:one).days_since_admission
    end
  end

  test "status_label reflects discharge state" do
    assert_equal "Discharged", hospitalizations(:one).status_label
    assert_equal "In Hospital", hospitalizations(:three).status_label
  end

  test "outcome_label and discharge_destination_label" do
    assert_equal "Recovered", hospitalizations(:one).outcome_label
    assert_equal "Home", hospitalizations(:one).discharge_destination_label

    assert_equal "-", hospitalizations(:three).outcome_label
    assert_equal "-", hospitalizations(:three).discharge_destination_label
  end

  test "discharged and in_hospital scopes" do
    assert_includes Hospitalization.discharged, hospitalizations(:one)
    assert_includes Hospitalization.discharged, hospitalizations(:two)
    assert_not_includes Hospitalization.discharged, hospitalizations(:three)

    assert_includes Hospitalization.in_hospital, hospitalizations(:three)
    assert_not_includes Hospitalization.in_hospital, hospitalizations(:one)
  end

  test "admitted_between scope filters by admission_date range" do
    result = Hospitalization.admitted_between(Date.new(2026, 3, 1), Date.new(2026, 3, 1))
    assert_includes result, hospitalizations(:one)
    assert_not_includes result, hospitalizations(:two)

    assert_includes Hospitalization.admitted_between(nil, nil), hospitalizations(:one)
    assert_includes Hospitalization.admitted_between(Date.new(2026, 3, 1), nil), hospitalizations(:three)
    assert_not_includes Hospitalization.admitted_between(nil, Date.new(2026, 3, 4)), hospitalizations(:two)
  end

  test "to_s renders patient and admission/discharge period" do
    assert_equal "H001 - John Doe (2026-03-01 - 2026-03-06)", hospitalizations(:one).to_s
    assert_equal "H001 - John Doe (2026-06-01 - in hospital)", hospitalizations(:three).to_s
  end

  test "surgeries are nullified when the hospitalization is destroyed" do
    surgery = Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalizations(:one),
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalizations(:one).destroy!

    assert_nil surgery.reload.hospitalization_id
  end
end
