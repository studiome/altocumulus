require "test_helper"

class PatientDiagnosesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @patient = patients(:one)
    @patient_diagnosis = patient_diagnoses(:appendicitis)
    @deletable_patient_diagnosis = patient_diagnoses(:hypertension)
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
        patient_diagnosis: { diagnosis_id: diagnoses(:fracture).id, laterality: "left", diagnosed_on: Date.new(2026, 4, 17) }
      }
    end

    assert_redirected_to patient_url(@patient)
    assert_equal diagnoses(:fracture), PatientDiagnosis.last.diagnosis
    assert_equal "left", PatientDiagnosis.last.laterality
  end

  test "should show patient diagnosis" do
    get patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    assert_response :success
  end

  test "should create patient diagnosis via json" do
    assert_difference("PatientDiagnosis.count") do
      post patient_patient_diagnoses_url(@patient, format: :json), params: {
        patient_diagnosis: { diagnosis_id: diagnoses(:fracture).id, laterality: "left", diagnosed_on: Date.new(2026, 4, 17) }
      }
    end

    assert_response :created
    assert_equal Mime[:json].to_s, response.media_type
    body = response.parsed_body
    assert_equal PatientDiagnosis.last.id, body["id"]
    assert_equal diagnoses(:fracture).name, body["diagnosis_name"]
  end

  test "should show patient diagnosis via json" do
    get patient_patient_diagnosis_url(@patient, @patient_diagnosis, format: :json)

    assert_response :success
    assert_equal Mime[:json].to_s, response.media_type
    body = response.parsed_body
    assert_equal @patient_diagnosis.id, body["id"]
    assert_equal @patient_diagnosis.display_name, body["display_name"]
  end

  test "should get index via json" do
    get patient_patient_diagnoses_url(@patient, format: :json)

    assert_response :success
    assert_equal Mime[:json].to_s, response.media_type
    body = response.parsed_body
    assert_equal @patient.patient_diagnoses.count, body.size
  end

  test "should get edit" do
    get edit_patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    assert_response :success
  end

  test "should update patient diagnosis" do
    patch patient_patient_diagnosis_url(@patient, @patient_diagnosis), params: {
      patient_diagnosis: { diagnosis_id: diagnoses(:updated_diagnosis).id, laterality: "bilateral", diagnosed_on: @patient_diagnosis.diagnosed_on }
    }

    assert_redirected_to patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    @patient_diagnosis.reload
    assert_equal diagnoses(:updated_diagnosis), @patient_diagnosis.diagnosis
    assert_equal "bilateral", @patient_diagnosis.laterality
  end

  test "should destroy patient diagnosis" do
    assert_difference("PatientDiagnosis.count", -1) do
      delete patient_patient_diagnosis_url(@patient, @deletable_patient_diagnosis)
    end

    assert_redirected_to patient_url(@patient)
  end

  test "should not destroy patient diagnosis used by surgery" do
    assert_no_difference("PatientDiagnosis.count") do
      delete patient_patient_diagnosis_url(@patient, @patient_diagnosis)
    end

    assert_redirected_to patient_patient_diagnosis_url(@patient, @patient_diagnosis)
  end
end
