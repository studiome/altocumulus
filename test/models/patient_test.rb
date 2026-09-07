require "test_helper"

class PatientTest < ActiveSupport::TestCase
  test "should be valid" do
    patient = Patient.new(hospital_id: "H004", name: "Alice Brown", date_of_birth: "1975-10-20")
    assert patient.valid?
  end

  test "destroy should destroy associated surgeries" do
    patient = patients(:one)
    Surgery.create!(
      patient: patient,
      surgery_date: Date.new(2026, 3, 1),
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

  test "filtered with blank keyword returns all patients" do
    assert_equal Patient.all.to_a.sort_by(&:id), Patient.filtered(keyword: "").to_a.sort_by(&:id)
    assert_equal Patient.all.to_a.sort_by(&:id), Patient.filtered(keyword: nil).to_a.sort_by(&:id)
  end

  test "filtered matches by partial name" do
    assert_equal [ patients(:one) ], Patient.filtered(keyword: "john").to_a
  end

  test "filtered matches by partial hospital_id" do
    assert_equal [ patients(:two) ], Patient.filtered(keyword: "H002").to_a
  end

  test "filtered escapes LIKE wildcards in keyword" do
    assert_equal [], Patient.filtered(keyword: "%").to_a
    assert_equal [], Patient.filtered(keyword: "_ohn").to_a
  end

  test "ordered scope orders by hospital_id" do
    assert_equal Patient.all.sort_by(&:hospital_id), Patient.ordered.to_a
  end

  test "age computes years from date_of_birth as of today" do
    travel_to Date.new(2026, 9, 7) do
      patient = Patient.new(hospital_id: "H100", name: "Ages", date_of_birth: Date.new(1980, 9, 6))
      assert_equal 46, patient.age

      patient.date_of_birth = Date.new(1980, 9, 7)
      assert_equal 46, patient.age

      patient.date_of_birth = Date.new(1980, 9, 8)
      assert_equal 45, patient.age
    end
  end

  test "age is nil when date_of_birth is blank" do
    patient = Patient.new(hospital_id: "H101", name: "No DOB")
    assert_nil patient.age
  end

  test "sex must be one of the allowed options but blank is allowed" do
    patient = Patient.new(hospital_id: "H102", name: "Sex Test", date_of_birth: "1990-01-01")
    assert patient.valid?

    patient.sex = "not_a_real_option"
    assert_not patient.valid?

    patient.sex = "female"
    assert patient.valid?
  end
end
