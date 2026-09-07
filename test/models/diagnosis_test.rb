require "test_helper"

class DiagnosisTest < ActiveSupport::TestCase
  test "should be valid" do
    diagnosis = Diagnosis.new(name: "Gastritis")

    assert diagnosis.valid?
  end

  test "should require name" do
    diagnosis = Diagnosis.new(name: nil)

    assert_not diagnosis.valid?
  end

  test "should require unique name" do
    diagnosis = Diagnosis.new(name: diagnoses(:pneumonia).name)

    assert_not diagnosis.valid?
  end

  # AuditEventsHelper#audit_change_value resolves a "*_id" attribute to
  # `record.to_s` so the audit trail reads as a name instead of a raw id --
  # without this, a hospitalization/patient diagnosis change in the audit log
  # renders as Ruby's default "#<Diagnosis:0x...>" object inspection.
  test "to_s renders the diagnosis name" do
    assert_equal "Pneumonia", diagnoses(:pneumonia).to_s
  end
end
