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

  test "Lateralizable laterality options are English by default and Japanese under ja" do
    assert_equal "Right", Lateralizable.laterality_options["right"]
    assert_equal "None", Lateralizable.laterality_options["none"]

    I18n.with_locale(:ja) do
      assert_equal "右", Lateralizable.laterality_options["right"]
      assert_equal "なし", Lateralizable.laterality_options["none"]
    end
  end

  test "laterality_label uses the localized 'none' label when laterality is none" do
    selection = surgery_procedure_selections(:one_appendectomy)
    selection.laterality = "none"
    assert_equal "None", selection.laterality_label

    I18n.with_locale(:ja) do
      assert_equal "なし", selection.laterality_label
    end
  end
end
