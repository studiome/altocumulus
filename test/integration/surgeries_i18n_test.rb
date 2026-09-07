require "test_helper"

# Stage 3 group 3b: locale coverage for the Surgeries views and controller
# flashes. Mirrors hospitalizations_i18n_test.rb's structure (see that file
# and en.yml/ja.yml for the conventions this follows).
class SurgeriesI18nTest < ActionDispatch::IntegrationTest
  setup do
    @surgery = surgeries(:one)     # Sunday 2026-03-01, undated hospitalization, no slot
    @elective = surgeries(:three)  # Tuesday 2026-03-03, elective, slot 1 of 3
  end

  test "index renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgeries_url

    assert_response :success
    assert_select "h1", text: "手術"
    assert_select "a", text: "新規手術"
    assert_select "th", text: "手術日"
    assert_select "th", text: "開始時刻"
    assert_select "th", text: "診断名"
    assert_select "th", text: "術式"
    assert_select "th", text: "手術時間"
    assert_select "th", text: "麻酔"
    assert_select "th", text: "患者"
    assert_select "th", text: "入院"
    assert_select "th", text: "操作"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "index renders in English unchanged" do
    sign_in_as(users(:member))

    get surgeries_url

    assert_response :success
    assert_select "h1", text: "Surgeries"
    assert_select "a", text: "New Surgery"
    assert_select "th", text: "Surgery Date"
    assert_select "th", text: "Start Time"
    assert_select "th", text: "Duration"
    assert_select "th", text: "Anesthesia"
    assert_select "th", text: "Patient"
    assert_select "th", text: "Hospitalization"
    assert_select "th", text: "Actions"
    assert_no_match(/手術/, response.body)
  end

  test "index empty state renders in Japanese when filtered" do
    sign_in_as(users(:japanese_member))

    get surgeries_url, params: { keyword: "nonexistent-keyword-zzz" }

    assert_response :success
    assert_match(/検索条件に一致する手術がありません/, response.body)
  end

  test "index surgery date renders in the Japanese date format" do
    sign_in_as(users(:japanese_member))

    get surgeries_url

    assert_response :success
    assert_match "2026年03月01日", response.body
  end

  test "index surgery date renders in the original English date format" do
    sign_in_as(users(:member))

    get surgeries_url

    assert_response :success
    assert_match "2026-03-01", response.body
  end

  test "index still shows the assigned slot count in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgeries_url

    assert_response :success
    assert_match(%r{第1枠 / 3}, response.body)
  end

  test "show renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "手術の詳細"
    assert_select "span", text: "関連する診断名"
    assert_select "div", text: "詳細情報"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "show renders in English unchanged" do
    sign_in_as(users(:member))

    get surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "Surgery Details"
    assert_select "span", text: "Related Diagnoses"
    assert_select "div", text: "Information"
  end

  test "show renders the surgery date in the Japanese long date format" do
    sign_in_as(users(:japanese_member))

    get surgery_url(@surgery)

    assert_response :success
    assert_match(/2026年03月01日/, response.body)
  end

  test "show renders the surgery date in the original English long date format" do
    sign_in_as(users(:member))

    get surgery_url(@surgery)

    assert_response :success
    assert_match(/March 01, 2026/, response.body)
  end

  test "show renders the slot badge in Japanese" do
    sign_in_as(users(:japanese_member))

    get surgery_url(@elective)

    assert_response :success
    assert_match(%r{第1枠 / 全3枠}, response.body)
  end

  test "new renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_surgery_url

    assert_response :success
    assert_select "h1", text: "新規手術"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "edit renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get edit_surgery_url(@surgery)

    assert_response :success
    assert_select "h1", text: "手術を編集"
    assert_select "a", text: "詳細を表示"
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "create flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post surgeries_url, params: { surgery: {
      patient_id: patients(:one).id,
      surgery_date: "2026-03-05",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: {
        "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      }
    } }

    follow_redirect!
    assert_match "手術記録を作成しました。", response.body
  end

  test "create flash notice renders in English unchanged" do
    sign_in_as(users(:member))

    post surgeries_url, params: { surgery: {
      patient_id: patients(:one).id,
      surgery_date: "2026-03-05",
      anesthesia_method: "General",
      duration_hours: 1.0,
      surgery_procedure_selections_attributes: {
        "0" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" }
      }
    } }

    follow_redirect!
    assert_match "Surgery was successfully created.", response.body
  end

  test "update flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    patch surgery_url(@surgery), params: { surgery: {
      patient_id: @surgery.patient_id,
      surgery_date: @surgery.surgery_date,
      anesthesia_method: @surgery.anesthesia_method,
      duration_hours: @surgery.duration_hours
    } }

    follow_redirect!
    assert_match "手術記録を更新しました。", response.body
  end

  test "destroy flash notice renders in Japanese" do
    sign_in_as(users(:japanese_member))

    delete surgery_url(@surgery)

    follow_redirect!
    assert_match "手術記録を削除しました。", response.body
  end

  test "form validation errors heading renders in Japanese" do
    sign_in_as(users(:japanese_member))

    post surgeries_url, params: { surgery: { patient_id: patients(:one).id, anesthesia_method: "" } }

    assert_response :unprocessable_entity
    assert_match(/件のエラーによりこの手術を保存できませんでした:/, response.body)
  end

  test "form validation errors heading pluralizes in English" do
    sign_in_as(users(:member))

    post surgeries_url, params: { surgery: { patient_id: patients(:one).id, anesthesia_method: "" } }

    assert_response :unprocessable_entity
    assert_match(/errors? prohibited this surgery from being saved:/, response.body)
  end

  test "no translation missing across the surgeries screens rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    [
      surgeries_url,
      surgery_url(@surgery),
      new_surgery_url,
      edit_surgery_url(@surgery)
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end
end
