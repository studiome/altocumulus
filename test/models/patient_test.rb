require "test_helper"

class PatientTest < ActiveSupport::TestCase
  test "should be valid" do
    patient = Patient.new(hospital_id: "H003", name: "Alice Brown", date_of_birth: "1975-10-20")
    assert patient.valid?
  end

  test "fixtures should be valid" do
    assert patients(:one).valid?
    assert patients(:two).valid?
  end
end
