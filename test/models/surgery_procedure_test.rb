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
end
