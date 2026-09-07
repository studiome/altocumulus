require "test_helper"

# Stage 3 group 2: locale coverage for the Patients views and controller
# flashes. English assertions guard byte-identical wording with what the
# screens rendered before i18n (existing tests already assert some of this
# in English); Japanese assertions confirm ja.yml's new `patients:` keys
# actually render.
class PatientsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @patient = patients(:one)
  end

  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get patients_url

    assert_response :success
    assert_select "h1", text: "患者"
    assert_select "a", text: "新規患者"
    assert_select "th", text: "患者ID"
    assert_select "th", text: "氏名"
    assert_select "th", text: "生年月日"
    assert_select "th", text: "操作"
    assert_select "a", text: "診断を追加"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get patients_url

    assert_response :success
    assert_select "h1", text: "Patients"
    assert_select "a", text: "New Patient"
    assert_select "th", text: "Hospital ID"
    assert_select "th", text: "Name"
    assert_select "th", text: "Date of Birth"
    assert_select "th", text: "Actions"
    assert_select "a", text: "Add Diagnosis"
    assert_no_match(/患者/, response.body)
  end

  test "index empty state renders in Japanese when filtered" do
    sign_in_as(users(:japanese_member))

    get patients_url, params: { keyword: "nonexistent-keyword-zzz" }

    assert_response :success
    assert_match(/条件に一致する患者がいません|検索条件に一致する患者/, response.body)
  end

  test "show renders in Japanese with a Japanese-formatted date of birth" do
    sign_in_as(users(:japanese_member))

    get patient_url(@patient)

    assert_response :success
    assert_select "h1", text: "患者の詳細"
    assert_select "span", text: "1980年01月01日"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "show renders in English unchanged with the original date format" do
    sign_in_as(users(:member))

    get patient_url(@patient)

    assert_response :success
    assert_select "h1", text: "Patient Details"
    assert_select "span", text: "January 01, 1980"
  end

  test "new renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_patient_url

    assert_response :success
    assert_select "h1", text: "新規患者"
  end

  test "edit renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get edit_patient_url(@patient)

    assert_response :success
    assert_select "h1", text: "患者を編集"
  end

  test "create flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post patients_url, params: { patient: { hospital_id: "H999", name: "テスト患者", date_of_birth: "1999-01-01" } }

    assert_redirected_to patient_url(Patient.order(:id).last)
    follow_redirect!
    assert_match "患者を作成しました。", response.body
  end

  test "create flash notice renders in English unchanged" do
    sign_in_as(users(:member))

    post patients_url, params: { patient: { hospital_id: "H998", name: "New Patient", date_of_birth: "1999-01-01" } }

    assert_redirected_to patient_url(Patient.order(:id).last)
    follow_redirect!
    assert_match "Patient was successfully created.", response.body
  end

  test "update flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    patch patient_url(@patient), params: { patient: { hospital_id: @patient.hospital_id, name: "更新後の名前", date_of_birth: @patient.date_of_birth } }

    follow_redirect!
    assert_match "患者を更新しました。", response.body
  end

  test "destroy flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    delete patient_url(@patient)

    follow_redirect!
    assert_match "患者を削除しました。", response.body
  end

  test "form validation errors heading pluralizes in English" do
    sign_in_as(users(:member))

    post patients_url, params: { patient: { hospital_id: "", name: "", date_of_birth: "" } }

    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this patient from being saved:/, response.body)
  end

  test "form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post patients_url, params: { patient: { hospital_id: "", name: "", date_of_birth: "" } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの患者を保存できませんでした:/, response.body)
  end
end
