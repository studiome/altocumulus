require "test_helper"

# Stage 3 group 2: locale coverage for the PatientDiagnoses views and
# controller flashes. Mirrors patients_i18n_test.rb's structure.
class PatientDiagnosesI18nTest < ActionDispatch::IntegrationTest
  setup do
    @patient = patients(:one)
    @patient_diagnosis = patient_diagnoses(:appendicitis)
    @deletable_patient_diagnosis = patient_diagnoses(:hypertension)
  end

  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get patient_patient_diagnoses_url(@patient)

    assert_response :success
    assert_select "h1", text: "診断"
    assert_select "th", text: "診断日"
    assert_select "th", text: "操作"
    assert_select "a", text: "診断を追加"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get patient_patient_diagnoses_url(@patient)

    assert_response :success
    assert_select "h1", text: "Diagnoses"
    assert_select "th", text: "Diagnosed On"
    assert_select "a", text: "Add Diagnosis"
  end

  test "index dates render in the Japanese date format" do
    sign_in_as(users(:japanese_member))

    get patient_patient_diagnoses_url(@patient)

    assert_response :success
    assert_match "2026年03月20日", response.body
  end

  test "index dates render in the original English date format" do
    sign_in_as(users(:member))

    get patient_patient_diagnoses_url(@patient)

    assert_response :success
    assert_match "2026-03-20", response.body
  end

  test "show renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get patient_patient_diagnosis_url(@patient, @patient_diagnosis)

    assert_response :success
    assert_select "h1", text: "診断エントリの詳細"
    assert_select "span", text: "診断名"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "show renders in English unchanged" do
    sign_in_as(users(:member))

    get patient_patient_diagnosis_url(@patient, @patient_diagnosis)

    assert_response :success
    assert_select "h1", text: "Diagnosis Entry Details"
    assert_select "span", text: "Diagnosis Name"
  end

  test "new renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_patient_patient_diagnosis_url(@patient)

    assert_response :success
    assert_select "h1", text: "新規診断エントリ"
    assert_select "option", text: "診断名を選択してください"
  end

  test "edit renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get edit_patient_patient_diagnosis_url(@patient, @patient_diagnosis)

    assert_response :success
    assert_select "h1", text: "診断エントリを編集"
  end

  test "create flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post patient_patient_diagnoses_url(@patient), params: {
      patient_diagnosis: { diagnosis_id: diagnoses(:fracture).id, laterality: "left", diagnosed_on: Date.new(2026, 4, 17) }
    }

    follow_redirect!
    assert_match "診断エントリを作成しました。", response.body
  end

  test "create flash notice renders in English unchanged" do
    sign_in_as(users(:member))

    post patient_patient_diagnoses_url(@patient), params: {
      patient_diagnosis: { diagnosis_id: diagnoses(:fracture).id, laterality: "left", diagnosed_on: Date.new(2026, 4, 17) }
    }

    follow_redirect!
    assert_match "Diagnosis entry was successfully created.", response.body
  end

  test "update flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    patch patient_patient_diagnosis_url(@patient, @patient_diagnosis), params: {
      patient_diagnosis: { diagnosis_id: diagnoses(:updated_diagnosis).id, laterality: "bilateral", diagnosed_on: @patient_diagnosis.diagnosed_on }
    }

    follow_redirect!
    assert_match "診断エントリを更新しました。", response.body
  end

  test "destroy flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    delete patient_patient_diagnosis_url(@patient, @deletable_patient_diagnosis)

    follow_redirect!
    assert_match "診断エントリを削除しました。", response.body
  end

  test "form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post patient_patient_diagnoses_url(@patient), params: { patient_diagnosis: { diagnosis_id: "", laterality: "none", diagnosed_on: "" } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの診断エントリを保存できませんでした:/, response.body)
  end
end
