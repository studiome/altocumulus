require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Surgeries views and controller flashes. English dates with their
# weekday on index/show are already asserted by surgeries_controller_test.rb
# ("index shows the weekday next to each surgery date...", "show displays the
# surgery date with its weekday"), so only the Japanese formats are checked here.
class SurgeriesI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup do
    @surgery = surgeries(:one)     # Sunday 2026-03-01, undated hospitalization, no slot
    @elective = surgeries(:three)  # Tuesday 2026-03-03, elective, slot 1 of 3
  end

  def surgery_params
    {
      patient_id: patients(:one).id,
      surgery_date: "2026-03-05",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: {
        "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      }
    }
  end

  test "index renders in Japanese and English" do
    get_as users(:japanese_member), surgeries_url, { all: "1" }

    assert_response :success
    assert_select "h1", text: "手術"
    assert_select "a", text: "新規手術"
    assert_select "th, th span", text: "手術日"
    assert_select "th, th span", text: "開始時刻"
    assert_select "th, th span", text: "診断名"
    assert_select "th, th span", text: "術式"
    assert_select "th, th span", text: "手術時間"
    assert_select "th, th span", text: "麻酔"
    assert_select "th, th span", text: "患者"
    assert_select "th, th span", text: "操作"
    assert_match "2026年03月01日", response.body
    assert_match(%r{第1枠 / 3}, response.body)

    get_as users(:member), surgeries_url

    assert_response :success
    assert_select "h1", text: "Surgeries"
    assert_select "a", text: "New Surgery"
    assert_select "th, th span", text: "Surgery Date"
    assert_select "th, th span", text: "Start Time"
    assert_select "th, th span", text: "Duration"
    assert_select "th, th span", text: "Anesthesia"
    assert_select "th, th span", text: "Patient"
    assert_select "th, th span", text: "Actions"
    assert_no_match(/手術/, response.body)
  end

  test "index empty state renders in Japanese when filtered" do
    get_as users(:japanese_member), surgeries_url, { keyword: "nonexistent-keyword-zzz" }

    assert_response :success
    assert_match(/検索条件に一致する手術がありません/, response.body)
  end

  test "show renders in Japanese and English" do
    get_as users(:japanese_member), surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "手術の詳細"
    assert_select "span", text: "関連する診断名"
    assert_select "div", text: "詳細情報"
    assert_match(/2026年03月01日\(日\)/, response.body)

    get surgery_url(@elective)
    assert_match(%r{第1枠 / 全3枠}, response.body)

    get_as users(:member), surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "Surgery Details"
    assert_select "span", text: "Related Diagnoses"
    assert_select "div", text: "Information"
  end

  test "new and edit render in Japanese" do
    get_as users(:japanese_member), new_surgery_url

    assert_response :success
    assert_select "h1", text: "新規手術"

    get edit_surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "手術を編集"
    assert_select "a", text: "詳細を表示"
  end

  test "flash messages render in Japanese and English" do
    sign_in_fresh(users(:japanese_member))

    post surgeries_url, params: { surgery: surgery_params }
    follow_redirect!
    assert_match "手術記録を作成しました。", response.body

    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours
    } }
    follow_redirect!
    assert_match "手術記録を更新しました。", response.body

    delete surgery_url(@surgery)
    follow_redirect!
    assert_match "手術記録を削除しました。", response.body

    sign_in_fresh(users(:member))

    post surgeries_url, params: { surgery: surgery_params }
    follow_redirect!
    assert_match "Surgery was successfully created.", response.body
  end

  test "form validation errors heading renders in Japanese and pluralizes in English" do
    invalid = { surgery: { patient_id: patients(:one).id, anesthesia_method: "" } }

    sign_in_fresh(users(:japanese_member))
    post surgeries_url, params: invalid
    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの手術を保存できませんでした:/, response.body)

    sign_in_fresh(users(:member))
    post surgeries_url, params: invalid
    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this surgery from being saved:/, response.body)
  end
end
