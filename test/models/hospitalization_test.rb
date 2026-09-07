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

  test "should require admission_date or scheduled_admission_date" do
    hospitalization = hospitalizations(:one)
    hospitalization.admission_date = nil
    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:admission_date], "or a scheduled admission date must be present"

    hospitalization.scheduled_admission_date = Date.new(2026, 9, 1)
    assert hospitalization.valid?
  end

  test "can be saved with only a scheduled_admission_date" do
    hospitalization = Hospitalization.new(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert hospitalization.valid?
    assert_nil hospitalization.admission_date
  end

  test "invalid date strings are rejected while blank fields are treated as undecided" do
    hospitalization = hospitalizations(:one)

    hospitalization.scheduled_admission_date = "not-a-date"
    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:scheduled_admission_date], "is not a valid date"

    hospitalization.scheduled_admission_date = ""
    assert hospitalization.valid?
    assert_nil hospitalization.scheduled_admission_date

    hospitalization.discharge_date = "also-not-a-date"
    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:discharge_date], "is not a valid date"
  end

  test "effective_admission_date prefers admission_date over scheduled_admission_date" do
    hospitalization = Hospitalization.new(admission_date: Date.new(2026, 5, 1), scheduled_admission_date: Date.new(2026, 4, 20))
    assert_equal Date.new(2026, 5, 1), hospitalization.effective_admission_date

    hospitalization.admission_date = nil
    assert_equal Date.new(2026, 4, 20), hospitalization.effective_admission_date

    hospitalization.scheduled_admission_date = nil
    assert_nil hospitalization.effective_admission_date
  end

  test "reservation_status must be one of the allowed options" do
    hospitalization = hospitalizations(:one)
    hospitalization.reservation_status = "not_a_real_status"
    assert_not hospitalization.valid?

    hospitalization.reservation_status = "waiting"
    assert hospitalization.valid?
  end

  test "purpose must be one of the allowed options" do
    hospitalization = hospitalizations(:one)
    hospitalization.purpose = "not_a_real_purpose"
    assert_not hospitalization.valid?

    hospitalization.purpose = "examination"
    assert hospitalization.valid?
  end

  test "reservation_status and purpose default to requested and surgery" do
    hospitalization = Hospitalization.new
    assert_equal "requested", hospitalization.reservation_status
    assert_equal "surgery", hospitalization.purpose
  end

  test "reservation_status_form_options and purpose_form_options mirror the option constants" do
    assert_equal Hospitalization.reservation_status_options.map { |k, v| [ v, k ] }, Hospitalization.reservation_status_form_options
    assert_equal Hospitalization.purpose_options.map { |k, v| [ v, k ] }, Hospitalization.purpose_form_options
  end

  test "admin_status defaults to unconfirmed" do
    assert_equal "unconfirmed", Hospitalization.new.admin_status
  end

  test "admin_status must be one of the allowed options" do
    hospitalization = hospitalizations(:one)
    hospitalization.admin_status = "not_a_real_status"
    assert_not hospitalization.valid?

    hospitalization.admin_status = "confirmed"
    assert hospitalization.valid?
  end

  test "admin_status_form_options mirrors the option constant" do
    assert_equal Hospitalization.admin_status_options.map { |k, v| [ v, k ] }, Hospitalization.admin_status_form_options
  end

  test "saving as a non-admin user resets admin_status to unconfirmed" do
    hospitalization = hospitalizations(:one)
    hospitalization.update!(admin_status: "confirmed") # simulate an already-confirmed record

    Current.user = users(:member)
    hospitalization.room_preference = "Updated by member"
    hospitalization.save!

    assert_equal "unconfirmed", hospitalization.reload.admin_status
  ensure
    Current.user = nil
  end

  test "saving as an admin user does not reset admin_status" do
    hospitalization = hospitalizations(:one)
    hospitalization.update!(admin_status: "confirmed")

    Current.user = users(:admin)
    hospitalization.room_preference = "Updated by admin"
    hospitalization.save!

    assert_equal "confirmed", hospitalization.reload.admin_status
  ensure
    Current.user = nil
  end

  test "saving with no Current.user does not reset admin_status (system/console actor)" do
    hospitalization = hospitalizations(:one)
    hospitalization.update!(admin_status: "confirmed")

    Current.user = nil
    hospitalization.room_preference = "Updated by console"
    hospitalization.save!

    assert_equal "confirmed", hospitalization.reload.admin_status
  end

  test "admin_status reset does not apply on create" do
    Current.user = users(:member)
    hospitalization = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_equal "unconfirmed", hospitalization.admin_status
  ensure
    Current.user = nil
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

  test "rejects overlap when the new hospitalization is reservation-only" do
    hospitalization = Hospitalization.new(
      patient: patients(:one),
      scheduled_admission_date: Date.new(2026, 3, 3),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:scheduled_admission_date], "overlaps another hospitalization for this patient"
  end

  test "rejects overlap when the existing hospitalization is reservation-only" do
    reservation = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    overlapping = Hospitalization.new(
      patient: patients(:two),
      admission_date: Date.new(2026, 9, 10),
      reason: "Fever",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:admission_date], "overlaps another hospitalization for this patient"
    assert overlapping.invalid?
    assert reservation.persisted?
  end

  test "rejects moving admission_date after a linked surgery date" do
    hospitalization = hospitalizations(:one)
    Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.admission_date = Date.new(2026, 3, 4)

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:admission_date], "must include all linked surgeries within the hospitalization period"
  end

  test "rejects moving discharge_date before a linked surgery date" do
    hospitalization = hospitalizations(:one)
    Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.discharge_date = Date.new(2026, 3, 2)

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:discharge_date], "must include all linked surgeries within the hospitalization period"
  end

  test "rejects a shrunken discharge_date even when surgeries was cached before the surgery was linked" do
    hospitalization = hospitalizations(:one)
    hospitalization.valid? # caches an empty `surgeries` association on this instance

    Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.discharge_date = Date.new(2026, 3, 2)

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:discharge_date], "must include all linked surgeries within the hospitalization period"
  end

  test "reports the discharge_date message only once even with several out-of-range surgeries" do
    hospitalization = hospitalizations(:one)
    2.times do
      Surgery.create!(
        patient: patients(:one),
        hospitalization: hospitalization,
        surgery_date: Date.new(2026, 3, 3),
        anesthesia_method: "General",
        duration_hours: 1.0,
        surgery_procedure_selections_attributes: [
          { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
        ]
      )
    end

    hospitalization.discharge_date = Date.new(2026, 3, 2)

    assert_not hospitalization.valid?
    assert_equal 1, hospitalization.errors[:discharge_date].count { |message| message == "must include all linked surgeries within the hospitalization period" }
  end

  test "linked surgeries must remain within the scheduled period when admission_date is not yet set" do
    hospitalization = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    Surgery.create!(
      patient: patients(:two),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 9, 12),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.scheduled_admission_date = Date.new(2026, 9, 13)

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:scheduled_admission_date], "must include all linked surgeries within the hospitalization period"
  end

  test "linked_surgeries_must_remain_within_period ignores an undated linked surgery" do
    hospitalization = hospitalizations(:one)
    Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: nil,
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    # Would fail with "must include all linked surgeries within the
    # hospitalization period" if the undated surgery were counted.
    hospitalization.discharge_date = Date.new(2026, 3, 2)

    assert hospitalization.valid?
  end

  test "rejects reassigning the patient while a surgery is linked" do
    hospitalization = hospitalizations(:one)
    Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.patient_id = patients(:two).id

    assert_not hospitalization.valid?
    assert_includes hospitalization.errors[:patient_id], "must match the patient of every linked surgery"
  end

  test "allows reassigning the patient when no surgeries are linked" do
    hospitalization = hospitalizations(:three)
    hospitalization.patient_id = patients(:two).id

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

  test "future admission is not in hospital and is scheduled" do
    travel_to Date.new(2026, 5, 31) do
      hospitalization = hospitalizations(:three)

      assert_not hospitalization.in_hospital?
      assert_nil hospitalization.days_since_admission
      assert_equal "Scheduled", hospitalization.status_label
    end
  end

  test "in_hospital scope excludes future admissions but includes today's admission" do
    travel_to Date.new(2026, 5, 31) do
      assert_not_includes Hospitalization.in_hospital, hospitalizations(:three)
    end

    travel_to Date.new(2026, 6, 1) do
      assert_includes Hospitalization.in_hospital, hospitalizations(:three)
      assert_equal 1, hospitalizations(:three).days_since_admission
    end
  end

  test "status_label reflects discharge state" do
    assert_equal "Discharged", hospitalizations(:one).status_label
    assert_equal "In Hospital", hospitalizations(:three).status_label
  end

  test "in_hospital?, status_label, and length_of_stay stay safe when admission_date is nil" do
    hospitalization = Hospitalization.new(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery"
    )

    assert_not hospitalization.in_hospital?
    assert_not hospitalization.discharged?
    assert_equal "Scheduled", hospitalization.status_label
    assert_nil hospitalization.length_of_stay
    assert_nil hospitalization.days_since_admission
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

  test "admitted_between scope falls back to scheduled_admission_date when admission_date is nil" do
    reservation = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 10),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    result = Hospitalization.admitted_between(Date.new(2026, 9, 1), Date.new(2026, 9, 30))
    assert_includes result, reservation

    assert_not_includes Hospitalization.admitted_between(Date.new(2026, 10, 1), nil), reservation
  end

  test "to_s renders patient and admission/discharge period" do
    assert_equal "H001 - John Doe (2026-03-01 - 2026-03-06)", hospitalizations(:one).to_s
    assert_equal "H001 - John Doe (2026-06-01 - in hospital)", hospitalizations(:three).to_s
  end

  test "discard! soft-deletes without removing the record" do
    hospitalization = hospitalizations(:one)
    hospitalization.discard!

    assert hospitalization.deleted?
    assert hospitalization.reload.deleted_at.present?
    assert Hospitalization.exists?(hospitalization.id)
  end

  test "restore! clears deleted_at" do
    hospitalization = hospitalizations(:one)
    hospitalization.discard!

    hospitalization.restore!

    assert_not hospitalization.deleted?
    assert_nil hospitalization.reload.deleted_at
  end

  test "active and discarded scopes partition on deleted_at" do
    hospitalization = hospitalizations(:one)
    hospitalization.discard!

    assert_not_includes Hospitalization.active, hospitalization
    assert_includes Hospitalization.discarded, hospitalization
    assert_includes Hospitalization.active, hospitalizations(:two)
    assert_not_includes Hospitalization.discarded, hospitalizations(:two)
  end

  test "discard! does not unlink surgeries" do
    hospitalization = hospitalizations(:one)
    surgery = Surgery.create!(
      patient: patients(:one),
      hospitalization: hospitalization,
      surgery_date: Date.new(2026, 3, 3),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    hospitalization.discard!

    assert_equal hospitalization.id, surgery.reload.hospitalization_id
  end

  test "filtered excludes discarded hospitalizations" do
    hospitalization = hospitalizations(:one)
    hospitalization.discard!

    assert_not_includes Hospitalization.filtered, hospitalization
  end

  test "captures a patient snapshot on create" do
    patient = patients(:two)
    patient.update!(name: "Snapshot Name", sex: "female", date_of_birth: Date.current - 40.years)

    hospitalization = Hospitalization.create!(
      patient: patient,
      scheduled_admission_date: Date.new(2026, 9, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )

    assert_equal "Snapshot Name", hospitalization.patient_name_snapshot
    assert_equal "female", hospitalization.patient_sex_snapshot
    assert_equal 40, hospitalization.patient_age_snapshot
  end

  test "recaptures the patient snapshot when patient_id changes" do
    hospitalization = hospitalizations(:three)
    other_patient = patients(:two)
    other_patient.update!(name: "New Assigned Patient", sex: "male", date_of_birth: Date.current - 55.years)

    hospitalization.update!(patient_id: other_patient.id)

    assert_equal "New Assigned Patient", hospitalization.patient_name_snapshot
    assert_equal "male", hospitalization.patient_sex_snapshot
    assert_equal 55, hospitalization.patient_age_snapshot
  end

  test "does not recapture the patient snapshot on an ordinary update" do
    hospitalization = Hospitalization.create!(
      patient: patients(:two),
      scheduled_admission_date: Date.new(2026, 9, 1),
      reason: "Planned surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
    )
    original_snapshot = hospitalization.patient_name_snapshot
    assert original_snapshot.present?

    patients(:two).update!(name: "Changed Later")
    hospitalization.update!(room_preference: "New room")

    assert_equal original_snapshot, hospitalization.reload.patient_name_snapshot
  end

  test "rebook creates a new requested/unconfirmed hospitalization without actuals, discharge info, or surgery links, but keeps diagnoses" do
    original = hospitalizations(:two)
    original.update!(admin_status: "confirmed")
    Surgery.create!(
      patient: original.patient,
      hospitalization: original,
      surgery_date: Date.new(2026, 3, 6),
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    copy = original.rebook(scheduled_admission_date: Date.new(2027, 1, 15))

    assert copy.persisted?
    assert_not_equal original.id, copy.id
    assert_equal Date.new(2027, 1, 15), copy.scheduled_admission_date
    assert_nil copy.admission_date
    assert_nil copy.discharge_date
    assert_nil copy.outcome
    assert_nil copy.discharge_destination
    assert_nil copy.deleted_at
    assert_equal "requested", copy.reservation_status
    assert_equal "unconfirmed", copy.admin_status
    assert_equal Date.current, copy.submitted_on
    assert_equal copy.diagnoses.ids.sort, original.diagnoses.ids.sort
    assert_equal 0, copy.surgeries.count
  end

  test "rebook does not persist with a blank scheduled_admission_date" do
    original = hospitalizations(:one)

    copy = original.rebook(scheduled_admission_date: "")

    assert_not copy.persisted?
    assert_includes copy.errors[:admission_date], "or a scheduled admission date must be present"
  end

  test "rebook does not persist with an invalid scheduled_admission_date" do
    original = hospitalizations(:one)

    copy = original.rebook(scheduled_admission_date: "not-a-date")

    assert_not copy.persisted?
    assert_includes copy.errors[:scheduled_admission_date], "is not a valid date"
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

  test "filtered with no filters returns everything" do
    assert_equal Hospitalization.count, Hospitalization.filtered(keyword: nil, diagnosis_id: nil, status: nil, admitted_from: nil, admitted_to: nil).count
  end

  test "filtered by keyword matches patient name, hospital_id, or reason" do
    assert_equal [ hospitalizations(:two) ], Hospitalization.filtered(keyword: "jane").to_a
    assert_equal [ hospitalizations(:two) ], Hospitalization.filtered(keyword: "H002").to_a
    assert_equal [ hospitalizations(:one) ], Hospitalization.filtered(keyword: "community-acquired").to_a
  end

  test "filtered by keyword escapes LIKE wildcards" do
    assert_equal [], Hospitalization.filtered(keyword: "%").to_a
  end

  test "filtered by diagnosis_id matches only hospitalizations linked to it" do
    assert_equal [ hospitalizations(:three) ], Hospitalization.filtered(diagnosis_id: diagnoses(:appendicitis).id).to_a
  end

  test "filtered by status in_hospital or discharged" do
    assert_equal [ hospitalizations(:three) ], Hospitalization.filtered(status: "in_hospital").to_a
    assert_equal [ hospitalizations(:one), hospitalizations(:two) ].sort_by(&:id),
                 Hospitalization.filtered(status: "discharged").to_a.sort_by(&:id)
  end

  test "filtered by admitted_from and admitted_to narrows the admission date range" do
    result = Hospitalization.filtered(admitted_from: "2026-03-04", admitted_to: "2026-03-31")
    assert_equal [ hospitalizations(:two) ], result.to_a
  end

  test "filtered combines multiple conditions" do
    result = Hospitalization.filtered(keyword: "john", status: "in_hospital")
    assert_equal [ hospitalizations(:three) ], result.to_a
  end

  test "filtered by status upcoming matches only future effective admission dates" do
    travel_to Date.new(2026, 9, 7) do
      future = build_hospitalization(reason: "Future reservation", scheduled_admission_date: Date.new(2026, 9, 10))
      past = build_hospitalization(reason: "Past admission", admission_date: Date.new(2026, 9, 1))

      result = Hospitalization.filtered(status: "upcoming")

      assert_includes result, future
      assert_not_includes result, past
    end
  end

  test "filtered by status waiting matches requested, waiting, or on_hold reservation_status" do
    waiting = build_hospitalization(reason: "Waiting case", reservation_status: "waiting")
    on_hold = build_hospitalization(reason: "On hold case", reservation_status: "on_hold")
    admitted = build_hospitalization(reason: "Already admitted", reservation_status: "admitted")

    result = Hospitalization.filtered(status: "waiting")

    assert_includes result, waiting
    assert_includes result, on_hold
    assert_not_includes result, admitted
  end

  test "filtered by status unconfirmed matches admin_status unconfirmed" do
    unconfirmed = build_hospitalization(reason: "Needs confirmation")
    confirmed = build_hospitalization(reason: "Already confirmed")
    confirmed.update!(admin_status: "confirmed")

    result = Hospitalization.filtered(status: "unconfirmed")

    assert_includes result, unconfirmed
    assert_not_includes result, confirmed
  end

  test "filtered by status recently_updated matches records updated within the last 2 days" do
    travel_to Date.new(2026, 9, 7) do
      recent = build_hospitalization(reason: "Recently touched")

      stale = build_hospitalization(reason: "Stale record")
      stale.update_column(:updated_at, 3.days.ago)

      result = Hospitalization.filtered(status: "recently_updated")

      assert_includes result, recent
      assert_not_includes result, stale
    end
  end

  test "filtered by status referred matches records with a referred_from present" do
    referred = build_hospitalization(reason: "Referred case", referred_from: "General Clinic")
    not_referred = build_hospitalization(reason: "Self admitted")

    result = Hospitalization.filtered(status: "referred")

    assert_includes result, referred
    assert_not_includes result, not_referred
  end

  test "filtered combines a new status filter with a keyword search" do
    waiting_match = build_hospitalization(reason: "Waiting and searchable", reservation_status: "waiting")
    waiting_no_match = build_hospitalization(reason: "Waiting but different", reservation_status: "waiting")

    result = Hospitalization.filtered(status: "waiting", keyword: "searchable")

    assert_includes result, waiting_match
    assert_not_includes result, waiting_no_match
  end

  private

    # Builds a persisted, non-overlapping hospitalization on its own fresh
    # patient so filter scenarios never trip the patient-level overlap
    # validation between test cases (or against the shared fixtures).
    def build_hospitalization(reason:, **attrs)
      patient = Patient.create!(hospital_id: "F#{SecureRandom.hex(4)}", name: "Filter Patient", date_of_birth: Date.new(1980, 1, 1))
      attrs[:scheduled_admission_date] ||= Date.new(2030, 1, 1) unless attrs[:admission_date]

      Hospitalization.create!(
        patient: patient,
        reason: reason,
        hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ],
        **attrs
      )
    end
end
