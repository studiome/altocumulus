require "test_helper"

class PatientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @patient = patients(:one)
  end

  test "should get index" do
    get patients_url
    assert_response :success
    assert_select "a[href='#{new_patient_patient_diagnosis_path(@patient)}']", text: "Add Diagnosis"
  end

  test "should get new" do
    get new_patient_url
    assert_response :success
  end

  test "should create patient" do
    assert_difference("Patient.count") do
      post patients_url, params: { patient: { date_of_birth: "1985-01-01", hospital_id: "H004", name: "New Patient" } }
    end

    assert_redirected_to patient_url(Patient.last)
  end

  test "should show patient" do
    get patient_url(@patient)
    assert_response :success
  end

  test "should get edit" do
    get edit_patient_url(@patient)
    assert_response :success
  end

  test "should update patient" do
    patch patient_url(@patient), params: { patient: { date_of_birth: @patient.date_of_birth, hospital_id: @patient.hospital_id, name: "Updated Name" } }
    assert_redirected_to patient_url(@patient)
    @patient.reload
    assert_equal "Updated Name", @patient.name
  end

  test "should destroy patient" do
    assert_difference("Patient.count", -1) do
      delete patient_url(@patient)
    end

    assert_redirected_to patients_url
  end
end
