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

    # Removes the singleton method again rather than redefining it, so the real
    # AuditEvent.create! (and its full signature) is what later tests see.
    def stubbing_audit_event_create_failure
      AuditEvent.define_singleton_method(:create!) { |*, **| raise ActiveRecord::RecordInvalid }
      yield
    ensure
      AuditEvent.singleton_class.send(:remove_method, :create!)
    end
end
