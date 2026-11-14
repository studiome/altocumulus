require "test_helper"

class EditVersionTest < ActiveSupport::TestCase
  test "a record without audit events has version 0" do
    AuditEvent.where(auditable_type: "Patient", auditable_id: patients(:one).id).delete_all

    assert_equal 0, EditVersion.for(patients(:one))
  end

  test "a real change grows the version, a no-op save does not" do
    patient = patients(:one)
    before = EditVersion.for(patient)

    patient.update!(name: patient.name)
    assert_equal before, EditVersion.for(patient)

    patient.update!(name: "Changed Name")
    assert_operator EditVersion.for(patient), :>, before
  end

  test "changes of a surgery's nested rows grow the surgery's version" do
    surgery = surgeries(:one)
    version = EditVersion.for(surgery)

    surgery.surgery_procedure_selections.first.update!(laterality: "bilateral")
    assert_operator EditVersion.for(surgery), :>, version
    version = EditVersion.for(surgery)

    surgery.surgery_procedure_selections.create!(surgery_procedure: surgery_procedures(:cholecystectomy), laterality: "none")
    assert_operator EditVersion.for(surgery), :>, version
    version = EditVersion.for(surgery)

    surgery.surgery_procedure_selections.last.destroy!
    assert_operator EditVersion.for(surgery), :>, version
    version = EditVersion.for(surgery)

    surgery.surgery_diagnosis_links.first.destroy!
    assert_operator EditVersion.for(surgery), :>, version
  end

  test "changes of a hospitalization's diagnosis rows and of discard / restore grow its version" do
    hospitalization = hospitalizations(:one)
    version = EditVersion.for(hospitalization)

    hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnoses(:asthma))
    assert_operator EditVersion.for(hospitalization), :>, version
    version = EditVersion.for(hospitalization)

    hospitalization.hospitalization_diagnoses.last.destroy!
    assert_operator EditVersion.for(hospitalization), :>, version
    version = EditVersion.for(hospitalization)

    hospitalization.discard!
    assert_operator EditVersion.for(hospitalization), :>, version
    version = EditVersion.for(hospitalization)

    hospitalization.restore
    assert_operator EditVersion.for(hospitalization), :>, version
  end

  test "a patient's diagnosis changes grow the patient's version" do
    patient = patients(:one)
    version = EditVersion.for(patient)

    patient.patient_diagnoses.create!(diagnosis: diagnoses(:asthma), laterality: "none", diagnosed_on: Date.new(2026, 4, 2))

    assert_operator EditVersion.for(patient), :>, version
  end

  test "several records give the highest version in one query" do
    patient = patients(:one)
    surgery = surgeries(:one)
    surgery.update!(operator_name: "Dr. Later")

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    version = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { EditVersion.for(patient, surgery, nil) }

    assert_equal 1, queries.size
    assert_equal [ EditVersion.for(patient), EditVersion.for(surgery) ].max, version
  end

  test "the changes since a token name who changed the record, once per user" do
    patient = patients(:one)
    token = EditVersion.for(patient)

    Current.set(user: users(:member)) { patient.update!(name: "First") }
    Current.set(user: users(:member)) { patient.update!(name: "Second") }
    Current.set(user: users(:admin)) { patient.update!(name: "Third") }

    editors = EditVersion.editors_since(token, patient)

    assert_equal [ "Admin User", "Member User" ].sort, editors.map(&:name).sort
    assert editors.all? { |editor| editor.at.present? }
  end

  test "no changes since the current token" do
    patient = patients(:one)

    assert_empty EditVersion.editors_since(EditVersion.for(patient), patient)
  end
end
