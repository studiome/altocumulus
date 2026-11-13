require "test_helper"

class SurgeryProcedureTest < ActiveSupport::TestCase
  test "filtered treats wildcard characters literally" do
    literal = SurgeryProcedure.create!(name: "Repair_A 50% type")
    SurgeryProcedure.create!(name: "RepairXA 500 type")

    assert_equal [ literal ], SurgeryProcedure.filtered(keyword: "Repair_A").to_a
    assert_equal [ literal ], SurgeryProcedure.filtered(keyword: "50%").to_a
  end

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

  test "filtered narrows the list by a case-insensitive partial name" do
    names = SurgeryProcedure.filtered(keyword: "endect").pluck(:name)

    assert_equal [ "Appendectomy" ], names
  end

  test "filtered returns every procedure when no keyword is given" do
    assert_equal SurgeryProcedure.count, SurgeryProcedure.filtered(keyword: nil).count
  end
end
