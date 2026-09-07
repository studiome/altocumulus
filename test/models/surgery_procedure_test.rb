require "test_helper"

class SurgeryProcedureTest < ActiveSupport::TestCase
  test "should be valid" do
    surgery_procedure = SurgeryProcedure.new(name: "Hernia repair")

    assert surgery_procedure.valid?
  end

  test "should require name" do
    surgery_procedure = SurgeryProcedure.new(name: nil)

    assert_not surgery_procedure.valid?
  end

  test "should require unique name" do
    surgery_procedure = SurgeryProcedure.new(name: surgery_procedures(:appendectomy).name)

    assert_not surgery_procedure.valid?
  end

  test "should not destroy surgery procedure in use by selections" do
    procedure = surgery_procedures(:appendectomy)
    assert_no_difference("SurgeryProcedure.count") do
      assert_not procedure.destroy
    end
    assert procedure.errors[:base].any?
  end

  # AuditEventsHelper#audit_change_value resolves a "*_id" attribute to
  # `record.to_s` so the audit trail reads as a name instead of a raw id --
  # without this, a surgery_procedure_selection change in the audit log
  # renders as Ruby's default "#<SurgeryProcedure:0x...>" object inspection.
  test "to_s renders the surgery procedure name" do
    assert_equal "Appendectomy", surgery_procedures(:appendectomy).to_s
  end
end
