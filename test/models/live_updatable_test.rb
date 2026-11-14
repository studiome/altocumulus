require "test_helper"

class LiveUpdatableTest < ActiveSupport::TestCase
  test "a surgery broadcasts its old and new date, itself, its patient and hospitalization" do
    surgery = surgeries(:one)
    hospitalization = hospitalizations(:one)
    surgery.update_columns(hospitalization_id: hospitalization.id)
    surgery.reload

    updates = live_updates { surgery.update!(surgery_date: Date.new(2026, 5, 5)) }

    dates = updates.flat_map { |u| u[:dates] }
    records = updates.flat_map { |u| u[:records] }
    assert_includes dates, "2026-03-01"
    assert_includes dates, "2026-05-05"
    assert_includes dates, "2026-03-01" # the hospitalization's admission date
    assert_includes records, "Surgery:#{surgery.id}"
    assert_includes records, "Patient:#{surgery.patient_id}"
    assert_includes records, "Hospitalization:#{hospitalization.id}"
  end

  test "relinking a surgery names the previous and the new hospitalization" do
    surgery = surgeries(:one)
    old = hospitalizations(:one)
    surgery.update_columns(hospitalization_id: old.id)
    new_hospitalization = Hospitalization.create!(
      patient: surgery.patient, scheduled_admission_date: Date.new(2026, 2, 1), planned_days: 3, purpose: "surgery",
      hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ]
    )
    surgery.reload

    updates = live_updates { surgery.update!(hospitalization: new_hospitalization) }

    records = updates.flat_map { |u| u[:records] }
    assert_includes records, "Hospitalization:#{old.id}"
    assert_includes records, "Hospitalization:#{new_hospitalization.id}"
    assert_includes updates.flat_map { |u| u[:dates] }, "2026-02-01"
  end

  test "a destroyed surgery broadcasts its date and records" do
    surgery = surgeries(:one)

    updates = live_updates { surgery.destroy! }

    assert_includes updates.flat_map { |u| u[:dates] }, "2026-03-01"
    assert_includes updates.flat_map { |u| u[:records] }, "Surgery:#{surgery.id}"
  end

  test "a hospitalization broadcasts old and new dates, its surgeries and patients" do
    hospitalization = hospitalizations(:three)
    surgery = surgeries(:three)
    surgery.update_columns(hospitalization_id: hospitalization.id)
    old_date = hospitalization.admission_date

    updates = live_updates { hospitalization.update!(admission_date: old_date + 1) }

    dates = updates.flat_map { |u| u[:dates] }
    records = updates.flat_map { |u| u[:records] }
    assert_includes dates, old_date.iso8601
    assert_includes dates, (old_date + 1).iso8601
    assert_includes dates, surgery.surgery_date.iso8601
    assert_includes records, "Hospitalization:#{hospitalization.id}"
    assert_includes records, "Surgery:#{surgery.id}"
    assert_includes records, "Patient:#{hospitalization.patient_id}"
  end

  test "moving a hospitalization to another patient names both patients" do
    hospitalization = hospitalizations(:four)
    old_patient = hospitalization.patient

    records = live_records { hospitalization.update!(patient: patients(:two)) }

    assert_includes records, "Patient:#{old_patient.id}"
    assert_includes records, "Patient:#{patients(:two).id}"
  end

  test "a patient broadcasts the dates of its surgeries and hospitalizations" do
    patient = patients(:one)

    updates = live_updates { patient.update!(name: "Renamed") }

    dates = updates.flat_map { |u| u[:dates] }
    assert_includes dates, surgeries(:one).surgery_date.iso8601
    assert_includes dates, hospitalizations(:one).admission_date.iso8601
    assert_includes updates.flat_map { |u| u[:records] }, "Patient:#{patient.id}"
  end

  test "the payload never carries a name" do
    patient = patients(:one)
    payloads = capture_turbo_stream_broadcasts(LiveUpdate::STREAM) { patient.update!(name: "Secret Name") }

    assert_not_empty payloads
    payloads.each { |p| assert_not_includes p.to_s, "Secret" }
  end

  test "a patient diagnosis broadcasts its patient and the linked surgeries" do
    diagnosis = patient_diagnoses(:appendicitis)

    updates = live_updates { diagnosis.update!(diagnosed_on: Date.new(2026, 3, 21)) }

    assert_includes updates.flat_map { |u| u[:records] }, "Patient:#{diagnosis.patient_id}"
    assert_includes updates.flat_map { |u| u[:records] }, "Surgery:#{surgeries(:one).id}"
    assert_includes updates.flat_map { |u| u[:dates] }, "2026-03-01"
  end

  test "join rows delegate to their surgery" do
    selection = surgery_procedure_selections(:one_appendectomy)
    updates = live_updates { selection.update!(laterality: "left") }
    assert_includes updates.flat_map { |u| u[:records] }, "Surgery:#{selection.surgery_id}"
    assert_includes updates.flat_map { |u| u[:dates] }, "2026-03-01"

    link = surgery_diagnosis_links(:one_appendicitis)
    records = live_records { link.destroy! }
    assert_includes records, "Surgery:#{link.surgery_id}"
  end

  test "a hospitalization diagnosis delegates to its hospitalization" do
    row = hospitalization_diagnoses(:one_pneumonia)

    records = live_records { row.update!(updated_at: Time.current) }
    assert_includes records, "Hospitalization:#{row.hospitalization_id}"
  end

  test "holidays and day overrides broadcast their date, old and new" do
    holiday = holidays(:national_holiday)
    dates = live_dates { holiday.update!(date: Date.new(2026, 3, 11)) }
    assert_includes dates, "2026-03-10"
    assert_includes dates, "2026-03-11"

    override = SpecialSlotDayOverride.new(resource: surgery_locations(:cath_lab), date: Date.new(2026, 3, 3), slot_count: 2)
    assert_includes live_dates { override.save! }, "2026-03-03"
    assert_includes live_dates { override.destroy! }, "2026-03-03"
  end

  test "weekly rules broadcast all" do
    rule = ElectiveSlotRule.first
    assert live_updates { rule.update!(slot_duration_minutes: rule.slot_duration_minutes + 1) }.any? { |u| u[:all] }

    assert live_updates { AdmissionThresholdRule.create!(day_of_week: 1, threshold: 3) }.any? { |u| u[:all] }

    special = SpecialSlotRule.new(resource: surgery_locations(:cath_lab), day_of_week: 2, slot_count: 1)
    assert live_updates { special.save! }.any? { |u| u[:all] }
  end
end
