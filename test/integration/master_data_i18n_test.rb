require "test_helper"

# Stage 3 (view text externalization), group 1: Diagnoses / SurgeryProcedures /
# Holidays / ElectiveSlotRules -- the four "master data" screens -- plus
# their controllers' flash messages. Exercises both locales end to end
# (rather than only at the model/helper unit level, per the pattern set by
# LocaleI18nTest) so a missing key or an accidentally-changed English string
# is caught at the same layer a real request would hit it.
class MasterDataI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  # ---------------------------------------------------------------------
  # translation missing coverage (index/show/new/edit for all four models)
  # ---------------------------------------------------------------------

  test "no translation missing on master data screens rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    diagnosis = diagnoses(:appendicitis)
    surgery_procedure = surgery_procedures(:appendectomy)
    holiday = holidays(:national_holiday)
    elective_slot_rule = elective_slot_rules(:tuesday)

    [
      diagnoses_url,
      new_diagnosis_url,
      diagnosis_url(diagnosis),
      edit_diagnosis_url(diagnosis),
      surgery_procedures_url,
      new_surgery_procedure_url,
      surgery_procedure_url(surgery_procedure),
      edit_surgery_procedure_url(surgery_procedure),
      holidays_url,
      new_holiday_url,
      holiday_url(holiday),
      edit_holiday_url(holiday),
      elective_slot_rules_url,
      new_elective_slot_rule_url,
      elective_slot_rule_url(elective_slot_rule),
      edit_elective_slot_rule_url(elective_slot_rule)
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  # ---------------------------------------------------------------------
  # Japanese rendering
  # ---------------------------------------------------------------------

  test "diagnoses screens render in Japanese" do
    sign_in_as(users(:japanese_member))
    diagnosis = diagnoses(:appendicitis)

    get diagnoses_url
    assert_select "h1", text: "診断名"
    assert_select "a", text: "新規診断名"
    assert_select "th", text: "操作"
    assert_select "a", text: "編集"
    assert_select "button", text: "削除"

    get new_diagnosis_url
    assert_select "h1", text: "新規診断名"
    assert_select "label", text: "診断名"

    get diagnosis_url(diagnosis)
    assert_select "h1", text: "診断名の詳細"
    assert_select "a", text: "診断名を編集"

    get edit_diagnosis_url(diagnosis)
    assert_select "h1", text: "診断名を編集"
    assert_select "a", text: "詳細を表示"
  end

  test "surgery procedures screens render in Japanese" do
    sign_in_as(users(:japanese_member))
    surgery_procedure = surgery_procedures(:appendectomy)

    get surgery_procedures_url
    assert_select "h1", text: "術式"
    assert_select "a", text: "新規術式"

    get surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "術式の詳細"
    assert_select "a", text: "術式を編集"

    get edit_surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "術式を編集"
  end

  test "holidays screens render in Japanese" do
    sign_in_as(users(:japanese_member))
    holiday = holidays(:national_holiday)

    get holidays_url
    assert_select "h1", text: "休日"
    assert_select "a", text: "新規休日"
    assert_select "th", text: "日付"
    assert_select "th", text: "備考"
    assert_select "span", text: "休診"

    get holiday_url(holiday)
    assert_select "h1", text: "休日の詳細"
    assert_select "span", text: "休診"

    get edit_holiday_url(holiday)
    assert_select "h1", text: "休日を編集"
    assert_select "label", text: "休日名"
  end

  test "elective slot rules screens render in Japanese" do
    sign_in_as(users(:japanese_member))
    rule = elective_slot_rules(:tuesday)

    get elective_slot_rules_url
    assert_select "h1", text: "手術枠ルール"
    assert_select "th", text: "曜日"

    get elective_slot_rule_url(rule)
    assert_select "h1", text: "手術枠ルールの詳細"

    get edit_elective_slot_rule_url(rule)
    assert_select "h1", text: "手術枠ルールを編集"
  end

  # ---------------------------------------------------------------------
  # English rendering stays byte-identical to the pre-i18n text
  # ---------------------------------------------------------------------

  test "diagnoses screens render unchanged in English" do
    sign_in_as(users(:member))
    diagnosis = diagnoses(:appendicitis)

    get diagnoses_url
    assert_select "h1", text: "Diagnoses"
    assert_select "a", text: "New Diagnosis"
    assert_select "th", text: "Actions"
    assert_select "a", text: "Edit"
    assert_select "button", text: "Delete"

    get diagnosis_url(diagnosis)
    assert_select "h1", text: "Diagnosis Details"
    assert_select "a", text: "Edit Diagnosis"

    get edit_diagnosis_url(diagnosis)
    assert_select "h1", text: "Edit Diagnosis"
    assert_select "a", text: "Show Detail"
  end

  test "surgery procedures screens render unchanged in English" do
    sign_in_as(users(:member))
    surgery_procedure = surgery_procedures(:appendectomy)

    get surgery_procedures_url
    assert_select "h1", text: "Surgery Procedures"
    assert_select "a", text: "New Procedure"

    get surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "Surgery Procedure Details"
    assert_select "a", text: "Edit Procedure"
  end

  test "holidays screens render unchanged in English" do
    sign_in_as(users(:member))
    holiday = holidays(:national_holiday)

    get holidays_url
    assert_select "h1", text: "Holidays"
    assert_select "th", text: "Date"
    assert_select "span", text: "Closed"

    get holiday_url(holiday)
    assert_select "h1", text: "Holiday Details"
  end

  test "elective slot rules screens render unchanged in English" do
    sign_in_as(users(:member))
    rule = elective_slot_rules(:tuesday)

    get elective_slot_rules_url
    assert_select "h1", text: "Elective Slot Rules"
    assert_select "th", text: "Day"

    get elective_slot_rule_url(rule)
    assert_select "h1", text: "Elective Slot Rule Details"
  end

  # ---------------------------------------------------------------------
  # flash messages
  # ---------------------------------------------------------------------

  test "diagnosis flash messages render in Japanese" do
    sign_in_as(users(:japanese_member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine" } }
    assert_equal "診断名を作成しました。", flash[:notice]

    diagnosis = Diagnosis.last
    patch diagnosis_url(diagnosis), params: { diagnosis: { name: "Updated" } }
    assert_equal "診断名を更新しました。", flash[:notice]

    delete diagnosis_url(diagnosis)
    assert_equal "診断名を削除しました。", flash[:notice]
  end

  test "diagnosis flash messages render unchanged in English" do
    sign_in_as(users(:member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine" } }
    assert_equal "Diagnosis was successfully created.", flash[:notice]

    diagnosis = Diagnosis.last
    patch diagnosis_url(diagnosis), params: { diagnosis: { name: "Updated" } }
    assert_equal "Diagnosis was successfully updated.", flash[:notice]

    delete diagnosis_url(diagnosis)
    assert_equal "Diagnosis was successfully destroyed.", flash[:notice]
  end

  test "surgery procedure flash messages render in Japanese" do
    sign_in_as(users(:japanese_member))

    post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } }
    assert_equal "術式を作成しました。", flash[:notice]

    surgery_procedure = SurgeryProcedure.last
    patch surgery_procedure_url(surgery_procedure), params: { surgery_procedure: { name: "Updated" } }
    assert_equal "術式を更新しました。", flash[:notice]

    delete surgery_procedure_url(surgery_procedure)
    assert_equal "術式を削除しました。", flash[:notice]
  end

  test "holiday flash messages render in Japanese" do
    sign_in_as(users(:japanese_member))

    post holidays_url, params: { holiday: { date: "2026-11-03", name: "Culture Day" } }
    assert_equal "休日を作成しました。", flash[:notice]

    holiday = Holiday.last
    patch holiday_url(holiday), params: { holiday: { name: "Updated" } }
    assert_equal "休日を更新しました。", flash[:notice]

    delete holiday_url(holiday)
    assert_equal "休日を削除しました。", flash[:notice]
  end

  test "elective slot rule flash messages render in Japanese" do
    sign_in_as(users(:japanese_member))

    post elective_slot_rules_url, params: { elective_slot_rule: { day_of_week: 4, slot_count: 2, slot_duration_minutes: 120 } }
    assert_equal "手術枠ルールを作成しました。", flash[:notice]

    rule = ElectiveSlotRule.last
    patch elective_slot_rule_url(rule), params: { elective_slot_rule: { slot_count: 3 } }
    assert_equal "手術枠ルールを更新しました。", flash[:notice]

    delete elective_slot_rule_url(rule)
    assert_equal "手術枠ルールを削除しました。", flash[:notice]
  end

  # ---------------------------------------------------------------------
  # date formatting via l()
  # ---------------------------------------------------------------------

  test "holiday dates render with the Japanese date format in Japanese locale" do
    sign_in_as(users(:japanese_member))
    holiday = holidays(:national_holiday)

    get holidays_url
    assert_match(/2026年03月10日/, response.body)

    get holiday_url(holiday)
    assert_match(/2026年03月10日\(火\)/, response.body)
  end

  test "holiday dates render unchanged in English locale" do
    sign_in_as(users(:member))
    holiday = holidays(:national_holiday)

    get holidays_url
    assert_match(/2026-03-10/, response.body)

    get holiday_url(holiday)
    assert_match(/March 10, 2026 \(Tuesday\)/, response.body)
  end

  # ---------------------------------------------------------------------
  # turbo-stream modal creation success text (data-turbo-confirm text too)
  # ---------------------------------------------------------------------

  test "diagnosis modal creation success message renders in Japanese via turbo stream" do
    sign_in_as(users(:japanese_member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine with aura" } },
                         headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml", "Turbo-Frame" => "diagnosis_modal_frame" }

    assert_response :success
    assert_match("診断名を作成しました。", response.body)
  end

  test "delete confirmation prompt is translated in Japanese" do
    sign_in_as(users(:japanese_member))

    get diagnoses_url
    assert_match('data-turbo-confirm="本当によろしいですか?"', response.body)
  end

  test "delete confirmation prompt is unchanged in English" do
    sign_in_as(users(:member))

    get diagnoses_url
    assert_match('data-turbo-confirm="Are you sure?"', response.body)
  end
end
