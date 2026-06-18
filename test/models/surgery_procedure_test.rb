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
end
