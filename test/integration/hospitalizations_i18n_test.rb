require "test_helper"

# Stage 3 group 3a: locale coverage for the Hospitalizations views and
# controller flashes (including the admin-only confirm/restore/copy/deleted
# actions). Mirrors patients_i18n_test.rb / patient_diagnoses_i18n_test.rb's
# structure.
class HospitalizationsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @hospitalization = hospitalizations(:one)
    @reservation = hospitalizations(:two)
  end

  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get hospitalizations_url

    assert_response :success
    assert_select "h1", text: "入院"
    assert_select "a", text: "新規入院"
    assert_select "th", text: "予約ステータス"
    assert_select "th", text: "入院日"
    assert_select "th", text: "退院日"
    assert_select "th", text: "入院日数"
    assert_select "th", text: "希望病室"
    assert_select "th", text: "患者ID"
    assert_select "th", text: "操作"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get hospitalizations_url

    assert_response :success
    assert_select "h1", text: "Hospitalizations"
    assert_select "a", text: "New Hospitalization"
    assert_select "th", text: "Reservation Status"
    assert_select "th", text: "Admission Date"
    assert_select "th", text: "Discharge Date"
    assert_select "th", text: "Length of Stay"
    assert_select "th", text: "Preferred Room"
    assert_select "th", text: "Patient ID"
    assert_select "th", text: "Actions"
    assert_no_match(/入院/, response.body)
  end

  test "index empty state renders in Japanese when filtered" do
    sign_in_as(users(:japanese_member))

    get hospitalizations_url, params: { keyword: "nonexistent-keyword-zzz" }

    assert_response :success
    assert_match(/検索条件に一致する入院記録がありません/, response.body)
  end

  test "index planned days value renders in Japanese without changing the number" do
    sign_in_as(users(:japanese_member))

    get hospitalizations_url

    assert_response :success
    assert_match(/5日/, response.body)
  end

  test "index admission date renders in the Japanese date format" do
    sign_in_as(users(:japanese_member))

    get hospitalizations_url

    assert_response :success
    assert_match "2026年03月01日", response.body
  end

  test "index admission date renders in the original English date format" do
    sign_in_as(users(:member))

    get hospitalizations_url

    assert_response :success
    assert_match "2026-03-01", response.body
  end

  test "show renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "入院の詳細"
    assert_select "span", text: "入院時の診断名"
    assert_select "div", text: "更新履歴"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "show renders in English unchanged" do
    sign_in_as(users(:member))

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "Hospitalization Details"
    assert_select "span", text: "Diagnoses at Admission"
    assert_select "div", text: "Update History"
  end

  test "show renders dates in the Japanese long date format" do
    sign_in_as(users(:japanese_member))

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_match(/2026年03月01日/, response.body)
  end

  test "show renders dates in the original English long date format" do
    sign_in_as(users(:member))

    get hospitalization_url(@hospitalization)

    assert_response :success
    assert_match(/March 01, 2026/, response.body)
  end

  test "new renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_hospitalization_url

    assert_response :success
    assert_select "h1", text: "新規入院"
    assert_select "h2", text: "患者・予定"
    assert_select "h2", text: "入院・手術情報"
    assert_select "h2", text: "コメント"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "edit renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get edit_hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "入院を編集"
    assert_select "a", text: "詳細を表示"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "deleted list renders in Japanese for an admin" do
    sign_in_as(users(:japanese_admin))
    @hospitalization.discard!

    get deleted_hospitalizations_url

    assert_response :success
    assert_select "h1", text: "削除済み入院一覧"
    assert_select "th", text: "削除日時"
    assert_select "a", text: "詳細"
    assert_select "button", text: "復元"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "deleted list renders in English unchanged for an admin" do
    sign_in_as(users(:admin))
    @hospitalization.discard!

    get deleted_hospitalizations_url

    assert_response :success
    assert_select "h1", text: "Deleted Hospitalizations"
    assert_select "th", text: "Deleted At"
    assert_select "button", text: "Restore"
  end

  test "create flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id,
      admission_date: "2026-05-01",
      reason: "テスト入院",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }

    follow_redirect!
    assert_match "入院記録を作成しました。", response.body
  end

  test "create flash notice renders in English unchanged" do
    sign_in_as(users(:member))

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id,
      admission_date: "2026-05-01",
      reason: "Test admission",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }

    follow_redirect!
    assert_match "Hospitalization was successfully created.", response.body
  end

  test "update flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason
    } }

    follow_redirect!
    assert_match "入院記録を更新しました。", response.body
  end

  test "destroy flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    delete hospitalization_url(@hospitalization)

    follow_redirect!
    assert_match "入院記録を削除しました。", response.body
  end

  test "confirm flash notice renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    patch confirm_hospitalization_url(@hospitalization)

    follow_redirect!
    assert_match "入院を確認済みにしました。", response.body
  end

  test "confirm flash notice renders in English unchanged" do
    sign_in_as(users(:admin))

    patch confirm_hospitalization_url(@hospitalization)

    follow_redirect!
    assert_match "Hospitalization was confirmed.", response.body
  end

  test "restore flash notice renders in Japanese" do
    sign_in_as(users(:japanese_admin))
    @hospitalization.discard!

    patch restore_hospitalization_url(@hospitalization)

    follow_redirect!
    assert_match "入院記録を復元しました。", response.body
  end

  test "restore flash notice renders in English unchanged" do
    sign_in_as(users(:admin))
    @hospitalization.discard!

    patch restore_hospitalization_url(@hospitalization)

    follow_redirect!
    assert_match "Hospitalization was restored.", response.body
  end

  test "copy success flash notice renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "2027-03-01" }

    follow_redirect!
    assert_match "入院記録をコピーしました。残りの項目を入力してください。", response.body
  end

  test "copy success flash notice renders in English unchanged" do
    sign_in_as(users(:admin))

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "2027-03-01" }

    follow_redirect!
    assert_match "Hospitalization was copied. Fill in the remaining details.", response.body
  end

  test "copy failure flash alert renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "" }

    follow_redirect!
    assert_match(/コピーできませんでした:/, response.body)
  end

  test "copy failure flash alert renders in English unchanged" do
    sign_in_as(users(:admin))

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "" }

    follow_redirect!
    assert_match(/Could not copy:/, response.body)
  end

  test "form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post hospitalizations_url, params: { hospitalization: { patient_id: patients(:one).id, reason: "" } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの入院記録を保存できませんでした:/, response.body)
  end

  test "form validation errors heading pluralizes in English" do
    sign_in_as(users(:member))

    post hospitalizations_url, params: { hospitalization: { patient_id: patients(:one).id, reason: "" } }

    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this hospitalization from being saved:/, response.body)
  end

  test "no translation missing across the hospitalizations screens rendered in Japanese" do
    sign_in_as(users(:japanese_admin))
    @hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnoses(:fracture))
    hospitalizations(:two).discard!

    [
      hospitalizations_url,
      hospitalization_url(@hospitalization),
      new_hospitalization_url,
      edit_hospitalization_url(@hospitalization),
      deleted_hospitalizations_url
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end
end
