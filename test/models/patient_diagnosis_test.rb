require "test_helper"

class PatientDiagnosisTest < ActiveSupport::TestCase
  # AuditEventsHelper#audit_change_value resolves a "*_id" attribute to
  # `record.to_s` so the audit trail reads as a name instead of a raw id --
  # without this, a surgery_diagnosis_link change in the audit log renders as
  # Ruby's default "#<PatientDiagnosis:0x...>" object inspection.
  test "to_s renders the display_name" do
    assert_equal "Right Appendicitis", patient_diagnoses(:appendicitis).to_s
    assert_equal patient_diagnoses(:hypertension).display_name, patient_diagnoses(:hypertension).to_s
  end
end
