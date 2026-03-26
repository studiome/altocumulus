require "test_helper"

class PatientTest < ActiveSupport::TestCase
  test "should be valid" do
    patient = Patient.new(hospital_id: "H003", name: "Alice Brown", date_of_birth: "1975-10-20")
    assert patient.valid?
  end

  test "destroy should destroy associated surgeries" do
    patient = patients(:one)
    Surgery.create!(
      patient: patient,
      surgery_date: Date.new(2026, 3, 1),
      procedure: "Appendectomy",
      anesthesia_method: "General",
      duration_hours: 1.5,
      surgery_procedure_selections_attributes: [
        { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      ]
    )

    surgeries_count = patient.surgeries.count
    assert_difference("Surgery.count", -surgeries_count) do
      patient.destroy!
    end
  end

  test "fixtures should be valid" do
    assert patients(:one).valid?
    assert patients(:two).valid?
  end
end
