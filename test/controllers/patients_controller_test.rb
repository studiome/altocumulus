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

  test "index does not error out on a crafted Array page param" do
    get patients_url, params: { page: [ "1" ] }
    assert_response :success
  end

  test "index filters by keyword" do
    get patients_url, params: { keyword: "jane" }
    assert_response :success
    assert_select "td", text: "Jane Smith"
    assert_select "td", text: "John Doe", count: 0
  end

  test "index paginates results" do
    26.times { |i| Patient.create!(hospital_id: "P#{100 + i}", name: "Patient #{i}", date_of_birth: "1990-01-01") }

    get patients_url
    assert_response :success
    assert_select ".join .btn", text: "Next"

    get patients_url, params: { page: 2 }
    assert_response :success
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

  test "should create patient with clinical fields" do
    post patients_url, params: { patient: {
      date_of_birth: "1985-01-01", hospital_id: "H005", name: "New Patient",
      name_kana: "ニューペイシェント", sex: "female", telephone: "090-1111-2222",
      clinical_info: "No known allergies."
    } }

    patient = Patient.order(:id).last
    assert_redirected_to patient_url(patient)
    assert_equal "ニューペイシェント", patient.name_kana
    assert_equal "female", patient.sex
    assert_equal "090-1111-2222", patient.telephone
    assert_equal "No known allergies.", patient.clinical_info
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

  test "should update patient clinical fields" do
    patch patient_url(@patient), params: { patient: {
      date_of_birth: @patient.date_of_birth, hospital_id: @patient.hospital_id, name: @patient.name,
      name_kana: "ジョンドウ", sex: "male", telephone: "03-1234-5678", clinical_info: "Penicillin allergy."
    } }

    assert_redirected_to patient_url(@patient)
    @patient.reload
    assert_equal "ジョンドウ", @patient.name_kana
    assert_equal "male", @patient.sex
    assert_equal "03-1234-5678", @patient.telephone
    assert_equal "Penicillin allergy.", @patient.clinical_info
  end

  test "should destroy patient" do
    assert_difference("Patient.count", -1) do
      delete patient_url(@patient)
    end

    assert_redirected_to patients_url
  end
end
