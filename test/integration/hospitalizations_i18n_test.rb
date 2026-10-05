require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Hospitalizations views and controller flashes (including the
# admin-only confirm/restore/copy/deleted actions). English assertions that
# hospitalizations_controller_test.rb already makes (dates with weekday on
# index/show, the "Length of Stay" header, the new-form section headings, the
# deleted list "Restore" button) are not repeated here.
class HospitalizationsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup do
    @hospitalization = hospitalizations(:one)
    @reservation = hospitalizations(:two)
  end

  test "index renders in Japanese and English" do
    get_as users(:japanese_member), hospitalizations_url, { all: "1" }

    assert_response :success
    assert_select "h1", text: "入院"
    assert_select "a", text: "新規入院"
    assert_select "th, th span", text: "予約ステータス"
    assert_select "th, th span", text: "入院日"
    assert_select "th, th span", text: "退院日"
    assert_select "th, th span", text: "入院日数"
    assert_select "th, th span", text: "希望病室"
    assert_select "th, th span", text: "患者ID"
    assert_select "th, th span", text: "操作"
    assert_match(/5日/, response.body)
    assert_match "2026年03月01日", response.body

    get_as users(:member), hospitalizations_url

    assert_response :success
    assert_select "h1", text: "Hospitalizations"
    assert_select "a", text: "New Hospitalization"
    assert_select "th, th span", text: "Reservation Status"
    assert_select "th, th span", text: "Admission Date"
    assert_select "th, th span", text: "Discharge Date"
    assert_select "th, th span", text: "Preferred Room"
    assert_select "th, th span", text: "Patient ID"
    assert_select "th, th span", text: "Actions"
    assert_no_match(/入院/, response.body)
  end

  test "index empty state renders in Japanese when filtered" do
    get_as users(:japanese_member), hospitalizations_url, { keyword: "nonexistent-keyword-zzz" }

    assert_response :success
    assert_match(/検索条件に一致する入院記録がありません/, response.body)
  end

  test "show renders in Japanese and English" do
    get_as users(:japanese_member), hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "入院の詳細"
    assert_select "span", text: "入院時の診断名"
    assert_select "div", text: "更新履歴"
    assert_match(/2026年03月01日\(日\)/, response.body)

    get_as users(:member), hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "Hospitalization Details"
    assert_select "span", text: "Diagnoses at Admission"
    assert_select "div", text: "Update History"
  end

  test "new and edit render in Japanese" do
    get_as users(:japanese_member), new_hospitalization_url

    assert_response :success
    assert_select "h1", text: "新規入院"
    assert_select "h2", text: "患者・予定"
    assert_select "h2", text: "入院・手術情報"
    assert_select "h2", text: "コメント"

    get edit_hospitalization_url(@hospitalization)

    assert_response :success
    assert_select "h1", text: "入院を編集"
    assert_select "a", text: "詳細を表示"
  end

  test "deleted list renders in Japanese and English for an admin" do
    @hospitalization.discard!

    get_as users(:japanese_admin), deleted_hospitalizations_url

    assert_response :success
    assert_select "h1", text: "削除済み入院一覧"
    assert_select "th, th span", text: "削除日時"
    assert_select "a", text: "詳細"
    assert_select "button", text: "復元"

    get_as users(:admin), deleted_hospitalizations_url

    assert_response :success
    assert_select "h1", text: "Deleted Hospitalizations"
    assert_select "th, th span", text: "Deleted At"
  end

  test "flash messages render in Japanese" do
    sign_in_fresh(users(:japanese_admin))

    patch hospitalization_url(@hospitalization), params: { hospitalization: {
      patient_id: @hospitalization.patient_id,
      admission_date: @hospitalization.admission_date,
      reason: @hospitalization.reason
    } }
    follow_redirect!
    assert_match "入院記録を更新しました。", response.body

    patch confirm_hospitalization_url(@hospitalization)
    follow_redirect!
    assert_match "入院を確認済みにしました。", response.body

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "2027-03-01" }
    follow_redirect!
    assert_match "入院記録をコピーしました。残りの項目を入力してください。", response.body

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "" }
    follow_redirect!
    assert_match(/コピーできませんでした:/, response.body)

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id,
      admission_date: "2026-05-01",
      discharge_date: "2026-05-05",
      outcome: "recovered",
      reason: "テスト入院",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }
    follow_redirect!
    assert_match "入院記録を作成しました。", response.body

    delete hospitalization_url(@hospitalization)
    follow_redirect!
    assert_match "入院記録を削除しました。", response.body

    patch restore_hospitalization_url(@hospitalization)
    follow_redirect!
    assert_match "入院記録を復元しました。", response.body
  end

  test "flash messages render unchanged in English" do
    sign_in_fresh(users(:admin))

    patch confirm_hospitalization_url(@hospitalization)
    follow_redirect!
    assert_match "Hospitalization was confirmed.", response.body

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "2027-03-01" }
    follow_redirect!
    assert_match "Hospitalization was copied. Fill in the remaining details.", response.body

    post copy_hospitalization_url(@reservation), params: { scheduled_admission_date: "" }
    follow_redirect!
    assert_match(/Could not copy:/, response.body)

    @hospitalization.discard!
    patch restore_hospitalization_url(@hospitalization)
    follow_redirect!
    assert_match "Hospitalization was restored.", response.body

    post hospitalizations_url, params: { hospitalization: {
      patient_id: patients(:two).id,
      admission_date: "2026-05-01",
      discharge_date: "2026-05-05",
      outcome: "recovered",
      reason: "Test admission",
      hospitalization_diagnoses_attributes: { "0" => { diagnosis_id: diagnoses(:pneumonia).id } }
    } }
    follow_redirect!
    assert_match "Hospitalization was successfully created.", response.body
  end

  test "form validation errors heading renders in Japanese and pluralizes in English" do
    invalid = { hospitalization: { patient_id: patients(:one).id, reason: "" } }

    sign_in_fresh(users(:japanese_member))
    post hospitalizations_url, params: invalid
    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの入院記録を保存できませんでした:/, response.body)

    sign_in_fresh(users(:member))
    post hospitalizations_url, params: invalid
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this hospitalization from being saved:/, response.body)
  end
end
