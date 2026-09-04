require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "records create update and destroy for auditable models" do
    patient = Patient.create!(hospital_id: "H-AUDIT", name: "Audit Patient", date_of_birth: Date.new(1985, 4, 12))

    created = AuditEvent.find_by!(auditable_type: "Patient", auditable_id: patient.id, action: "create")
    assert_equal patient.to_s, created.record_label
    assert_equal [ nil, "Audit Patient" ], created.change_data.fetch("name")

    patient.update!(name: "Updated Patient")

    updated = AuditEvent.find_by!(auditable_type: "Patient", auditable_id: patient.id, action: "update")
    assert_equal [ "Audit Patient", "Updated Patient" ], updated.change_data.fetch("name")
    assert_not_includes updated.change_data.keys, "created_at"
    assert_not_includes updated.change_data.keys, "updated_at"

    patient.destroy!

    destroyed = AuditEvent.find_by!(auditable_type: "Patient", auditable_id: patient.id, action: "destroy")
    assert_equal "H-AUDIT - Updated Patient", destroyed.record_label
    assert_equal [ "Updated Patient", nil ], destroyed.change_data.fetch("name")
    assert AuditEvent.exists?(destroyed.id)
  end

  test "records surgery and hospitalization changes" do
    surgery = surgeries(:one)
    hospitalization = hospitalizations(:one)

    assert_difference("AuditEvent.count", 2) do
      surgery.update!(anesthesia_method: "Local")
      hospitalization.update!(room_preference: "Shared room")
    end

    assert_equal [ "General", "Local" ], AuditEvent.where(auditable_type: "Surgery").last.change_data["anesthesia_method"]
    assert_equal [ "Private room", "Shared room" ], AuditEvent.where(auditable_type: "Hospitalization").last.change_data["room_preference"]
  end

  test "records a stable human-readable surgery label" do
    surgery = surgeries(:one)

    surgery.update!(anesthesia_method: "Local")

    event = AuditEvent.where(auditable_type: "Surgery", auditable_id: surgery.id, action: "update").last
    assert_equal "2026-03-01 - H001 - John Doe", event.record_label
  end

  test "does not record update when only timestamps change" do
    patient = patients(:one)

    assert_no_difference("AuditEvent.count") do
      patient.update!(updated_at: patient.updated_at + 1.minute)
    end
  end

  test "records an update when a hospitalization destroy nullifies its surgeries" do
    hospitalization = hospitalizations(:one)
    surgery = surgeries(:one)
    surgery.update_columns(hospitalization_id: hospitalization.id)

    assert_difference("AuditEvent.where(auditable_type: 'Surgery', action: 'update').count", 1) do
      hospitalization.destroy!
    end

    assert_nil surgery.reload.hospitalization_id
    event = AuditEvent.where(auditable_type: "Surgery", auditable_id: surgery.id, action: "update").last
    assert_equal [ hospitalization.id, nil ], event.change_data.fetch("hospitalization_id")
  end

  test "records surgery procedure selection changes against its surgery" do
    surgery = surgeries(:two)
    selection = surgery.surgery_procedure_selections.create!(
      surgery_procedure: surgery_procedures(:appendectomy), laterality: "right"
    )

    created = latest_associated_event(surgery)
    assert_equal [ nil, surgery_procedures(:appendectomy).id ],
                 created.change_data.fetch(associated_key(selection, :surgery_procedure_id))
    assert_equal [ "none", "right" ], created.change_data.fetch(associated_key(selection, :laterality))
    assert_no_match(/(?:created_at|updated_at|surgery_id)\z/, created.change_data.keys.join("\n"))

    selection.update!(laterality: "left")

    updated = latest_associated_event(surgery)
    assert_equal [ "right", "left" ], updated.change_data.fetch(associated_key(selection, :laterality))

    selection.destroy!

    destroyed = latest_associated_event(surgery)
    assert_equal [ "left", nil ], destroyed.change_data.fetch(associated_key(selection, :laterality))
    assert_equal [ surgery_procedures(:appendectomy).id, nil ],
                 destroyed.change_data.fetch(associated_key(selection, :surgery_procedure_id))
  end

  test "records surgery diagnosis link changes against its surgery" do
    surgery = surgeries(:one)
    existing_link = surgery.surgery_diagnosis_links.first
    existing_link.destroy!

    link = surgery.surgery_diagnosis_links.create!(patient_diagnosis: patient_diagnoses(:hypertension))

    created = latest_associated_event(surgery)
    assert_equal [ nil, patient_diagnoses(:hypertension).id ],
                 created.change_data.fetch(associated_key(link, :patient_diagnosis_id))

    link.update!(patient_diagnosis: patient_diagnoses(:appendicitis))

    updated = latest_associated_event(surgery)
    assert_equal [ patient_diagnoses(:hypertension).id, patient_diagnoses(:appendicitis).id ],
                 updated.change_data.fetch(associated_key(link, :patient_diagnosis_id))

    link.destroy!

    destroyed = latest_associated_event(surgery)
    assert_equal [ patient_diagnoses(:appendicitis).id, nil ],
                 destroyed.change_data.fetch(associated_key(link, :patient_diagnosis_id))
  end

  test "records hospitalization diagnosis changes against its hospitalization" do
    hospitalization = hospitalizations(:one)
    hospitalization.hospitalization_diagnoses.find_by!(diagnosis: diagnoses(:hypertension)).destroy!

    link = hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnoses(:fracture))

    created = latest_associated_event(hospitalization)
    assert_equal [ nil, diagnoses(:fracture).id ], created.change_data.fetch(associated_key(link, :diagnosis_id))

    link.update!(diagnosis: diagnoses(:hypertension))

    updated = latest_associated_event(hospitalization)
    assert_equal [ diagnoses(:fracture).id, diagnoses(:hypertension).id ],
                 updated.change_data.fetch(associated_key(link, :diagnosis_id))

    link.destroy!

    destroyed = latest_associated_event(hospitalization)
    assert_equal [ diagnoses(:hypertension).id, nil ], destroyed.change_data.fetch(associated_key(link, :diagnosis_id))
  end

  test "records patient diagnosis create update and destroy against its patient" do
    patient = patients(:one)
    diagnosis = patient.patient_diagnoses.create!(
      diagnosis: diagnoses(:fracture), laterality: "right", diagnosed_on: Date.new(2026, 5, 1)
    )

    created = latest_associated_event(patient)
    assert_equal [ nil, diagnoses(:fracture).id ], created.change_data.fetch(associated_key(diagnosis, :diagnosis_id))
    assert_equal [ "none", "right" ], created.change_data.fetch(associated_key(diagnosis, :laterality))
    assert_equal [ nil, "2026-05-01" ], created.change_data.fetch(associated_key(diagnosis, :diagnosed_on))

    diagnosis.update!(laterality: "left")

    updated = latest_associated_event(patient)
    assert_equal [ "right", "left" ], updated.change_data.fetch(associated_key(diagnosis, :laterality))

    diagnosis.destroy!

    destroyed = latest_associated_event(patient)
    assert_equal [ "left", nil ], destroyed.change_data.fetch(associated_key(diagnosis, :laterality))
    assert_equal [ "2026-05-01", nil ], destroyed.change_data.fetch(associated_key(diagnosis, :diagnosed_on))
  end

  test "does not create associated update events while destroying a parent" do
    surgery = surgeries(:one)
    hospitalization = hospitalizations(:one)
    patient = Patient.create!(hospital_id: "H-AUDIT-DEPENDENT", name: "Dependent", date_of_birth: Date.new(1985, 4, 12))
    patient.patient_diagnoses.create!(diagnosis: diagnoses(:fracture), diagnosed_on: Date.new(2026, 5, 1))

    surgery_update_count = associated_update_count(surgery)
    hospitalization_update_count = associated_update_count(hospitalization)
    patient_update_count = associated_update_count(patient)

    surgery.destroy!
    hospitalization.destroy!
    patient.destroy!

    assert_equal surgery_update_count, associated_update_count(surgery)
    assert_equal hospitalization_update_count, associated_update_count(hospitalization)
    assert_equal patient_update_count, associated_update_count(patient)
  end

  test "rolls back an associated change when its audit event cannot be created" do
    surgery = surgeries(:two)
    procedure = surgery_procedures(:appendectomy)

    stubbing_audit_event_create_failure do
      assert_raises(ActiveRecord::RecordInvalid) do
        surgery.surgery_procedure_selections.create!(surgery_procedure: procedure, laterality: "right")
      end
    end

    assert_not surgery.surgery_procedure_selections.exists?(surgery_procedure: procedure)
  end

  test "validates action and filters by type and action" do
    event = AuditEvent.new(auditable_type: "Patient", auditable_id: 1, action: "publish", record_label: "Patient")
    assert_not event.valid?

    patient_event = AuditEvent.create!(auditable_type: "Patient", auditable_id: 1, action: "create", record_label: "Patient")
    surgery_event = AuditEvent.create!(auditable_type: "Surgery", auditable_id: 2, action: "update", record_label: "Surgery")

    assert_equal [ patient_event ], AuditEvent.filtered(auditable_type: "Patient", action: nil).to_a
    assert_equal [ surgery_event ], AuditEvent.filtered(auditable_type: nil, action: "update").to_a
  end

  test "audit failure rolls back the auditable save" do
    patient = Patient.new(hospital_id: "H-ROLLBACK", name: "Rollback", date_of_birth: Date.new(1990, 1, 1))

    stubbing_audit_event_create_failure do
      assert_raises(ActiveRecord::RecordInvalid) { patient.save! }
    end

    assert_not Patient.exists?(hospital_id: "H-ROLLBACK")

    # The stub must not outlive the block: create! keeps accepting a positional
    # hash, which a keyword-only replacement would reject.
    restored = AuditEvent.create!({ auditable_type: "Patient", auditable_id: 1, action: "create", record_label: "Positional hash" })
    assert_equal "Positional hash", restored.record_label
  end

  private

    def latest_associated_event(parent)
      AuditEvent.where(auditable_type: parent.class.name, auditable_id: parent.id, action: "update").order(:id).last.tap do |event|
        assert_not_nil event
        assert_equal parent.to_s, event.record_label
      end
    end

    def associated_update_count(parent)
      AuditEvent.where(auditable_type: parent.class.name, auditable_id: parent.id, action: "update").count
    end

    def associated_key(record, attribute)
      "#{record.model_name.singular}[#{record.id}].#{attribute}"
    end

    # Removes the singleton method again rather than redefining it, so the real
    # AuditEvent.create! (and its full signature) is what later tests see.
    def stubbing_audit_event_create_failure
      AuditEvent.define_singleton_method(:create!) { |*, **| raise ActiveRecord::RecordInvalid }
      yield
    ensure
      AuditEvent.singleton_class.send(:remove_method, :create!)
    end
end
