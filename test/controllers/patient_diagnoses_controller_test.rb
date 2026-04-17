require "test_helper"

class PatientDiagnosesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @patient = patients(:one)
    @patient_diagnosis = patient_diagnoses(:appendicitis)
  end

  test "should get index" do
    get patient_patient_diagnoses_url(@patient)
    assert_response :success
  end

  test "should get new" do
    get new_patient_patient_diagnosis_url(@patient)
    assert_response :success
  end

  test "should create patient diagnosis" do
    assert_difference("PatientDiagnosis.count") do
      post patient_patient_diagnoses_url(@patient), params: {
        patient_diagnosis: { diagnosis_id: diagnoses(:fracture).id, diagnosed_on: Date.new(2026, 4, 17) }
      }
    end

    assert_redirected_to patient_url(@patient)
    assert_equal diagnoses(:fracture), PatientDiagnosis.last.diagnosis
  end

  test "should show patient diagnosis" do
    get patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    assert_response :success
  end

  test "should get edit" do
    get edit_patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    assert_response :success
  end

  test "should update patient diagnosis" do
    patch patient_patient_diagnosis_url(@patient, @patient_diagnosis), params: {
      patient_diagnosis: { diagnosis_id: diagnoses(:updated_diagnosis).id, diagnosed_on: @patient_diagnosis.diagnosed_on }
    }

    assert_redirected_to patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    @patient_diagnosis.reload
    assert_equal diagnoses(:updated_diagnosis), @patient_diagnosis.diagnosis
  end

  test "should destroy patient diagnosis" do
    assert_difference("PatientDiagnosis.count", -1) do
      delete patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    end

    assert_redirected_to patient_url(@patient)
  end
end
