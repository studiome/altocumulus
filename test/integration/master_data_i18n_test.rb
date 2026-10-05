require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the four "master data" screens (Diagnoses / SurgeryProcedures /
# Holidays / ElectiveSlotRules) plus their controllers' flash messages. Each
# screen test looks at the page in Japanese and then in English (the English
# text must stay byte-identical to the pre-i18n wording). The English "Closed"
# badge on the holidays index is already asserted by holidays_controller_test.rb
# ("index distinguishes closed days from note-only days"), so it is not
# repeated here.
class MasterDataI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  # ---------------------------------------------------------------------
  # screens
  # ---------------------------------------------------------------------

  test "diagnoses screens render in Japanese and English" do
    diagnosis = diagnoses(:appendicitis)

    get_as users(:japanese_member), diagnoses_url
    assert_select "h1", text: "診断名"
    assert_select "a", text: "新規診断名"
    assert_select "th", text: "操作"
    assert_select "a", text: "編集"
    assert_select "button", text: "削除"
    assert_match('data-turbo-confirm="本当によろしいですか?"', response.body)

    get new_diagnosis_url
    assert_select "h1", text: "新規診断名"
    assert_select "label", text: "診断名"

    get diagnosis_url(diagnosis)
    assert_select "h1", text: "診断名の詳細"
    assert_select "a", text: "診断名を編集"

    get edit_diagnosis_url(diagnosis)
    assert_select "h1", text: "診断名を編集"
    assert_select "a", text: "詳細を表示"

    get_as users(:member), diagnoses_url
    assert_select "h1", text: "Diagnoses"
    assert_select "a", text: "New Diagnosis"
    assert_select "th", text: "Actions"
    assert_select "a", text: "Edit"
    assert_select "button", text: "Delete"
    assert_match('data-turbo-confirm="Are you sure?"', response.body)

    get diagnosis_url(diagnosis)
    assert_select "h1", text: "Diagnosis Details"
    assert_select "a", text: "Edit Diagnosis"

    get edit_diagnosis_url(diagnosis)
    assert_select "h1", text: "Edit Diagnosis"
    assert_select "a", text: "Show Detail"
  end

  test "surgery procedures screens render in Japanese and English" do
    surgery_procedure = surgery_procedures(:appendectomy)

    get_as users(:japanese_member), surgery_procedures_url
    assert_select "h1", text: "術式"
    assert_select "a", text: "新規術式"

    get surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "術式の詳細"
    assert_select "a", text: "術式を編集"

    get edit_surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "術式を編集"

    get_as users(:member), surgery_procedures_url
    assert_select "h1", text: "Surgery Procedures"
    assert_select "a", text: "New Procedure"

    get surgery_procedure_url(surgery_procedure)
    assert_select "h1", text: "Surgery Procedure Details"
    assert_select "a", text: "Edit Procedure"
  end

  test "holidays screens render in Japanese and English with the locale's date format" do
    holiday = holidays(:national_holiday)

    get_as users(:japanese_member), holidays_url
    assert_select "h1", text: "休日"
    assert_select "a", text: "新規休日"
    assert_select "th", text: "日付"
    assert_select "th", text: "備考"
    assert_select "span", text: "休診"
    assert_match(/2026年03月10日/, response.body)

    get holiday_url(holiday)
    assert_select "h1", text: "休日の詳細"
    assert_select "span", text: "休診"
    assert_match(/2026年03月10日\(火\)/, response.body)

    get edit_holiday_url(holiday)
    assert_select "h1", text: "休日を編集"
    assert_select "label", text: "休日名"

    get_as users(:member), holidays_url
    assert_select "h1", text: "Holidays"
    assert_select "th", text: "Date"
    assert_match(/2026-03-10/, response.body)

    get holiday_url(holiday)
    assert_select "h1", text: "Holiday Details"
    assert_match(/March 10, 2026 \(Tuesday\)/, response.body)
  end

  test "elective slot rules screens render in Japanese and English" do
    rule = elective_slot_rules(:tuesday)

    get_as users(:japanese_member), elective_slot_rules_url
    assert_select "h1", text: "手術枠ルール"
    assert_select "th", text: "曜日"

    get elective_slot_rule_url(rule)
    assert_select "h1", text: "手術枠ルールの詳細"

    get edit_elective_slot_rule_url(rule)
    assert_select "h1", text: "手術枠ルールを編集"

    get_as users(:member), elective_slot_rules_url
    assert_select "h1", text: "Elective Slot Rules"
    assert_select "th", text: "Day"

    get elective_slot_rule_url(rule)
    assert_select "h1", text: "Elective Slot Rule Details"
  end

  # ---------------------------------------------------------------------
  # flash messages
  # ---------------------------------------------------------------------

  test "diagnosis flash messages render in Japanese and English" do
    sign_in_fresh(users(:japanese_member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine" } }
    assert_equal "診断名を作成しました。", flash[:notice]

    diagnosis = Diagnosis.last
    patch diagnosis_url(diagnosis), params: { diagnosis: { name: "Updated" } }
    assert_equal "診断名を更新しました。", flash[:notice]

    delete diagnosis_url(diagnosis)
    assert_equal "診断名を削除しました。", flash[:notice]

    sign_in_fresh(users(:member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine" } }
    assert_equal "Diagnosis was successfully created.", flash[:notice]

    diagnosis = Diagnosis.last
    patch diagnosis_url(diagnosis), params: { diagnosis: { name: "Updated" } }
    assert_equal "Diagnosis was successfully updated.", flash[:notice]

    delete diagnosis_url(diagnosis)
    assert_equal "Diagnosis was successfully destroyed.", flash[:notice]
  end

  test "surgery procedure, holiday and elective slot rule flash messages render in Japanese" do
    sign_in_fresh(users(:japanese_member))

    post surgery_procedures_url, params: { surgery_procedure: { name: "Laparoscopy" } }
    assert_equal "術式を作成しました。", flash[:notice]

    surgery_procedure = SurgeryProcedure.last
    patch surgery_procedure_url(surgery_procedure), params: { surgery_procedure: { name: "Updated" } }
    assert_equal "術式を更新しました。", flash[:notice]

    delete surgery_procedure_url(surgery_procedure)
    assert_equal "術式を削除しました。", flash[:notice]

    post holidays_url, params: { holiday: { date: "2026-11-03", name: "Culture Day" } }
    assert_equal "休日を作成しました。", flash[:notice]

    holiday = Holiday.last
    patch holiday_url(holiday), params: { holiday: { name: "Updated" } }
    assert_equal "休日を更新しました。", flash[:notice]

    delete holiday_url(holiday)
    assert_equal "休日を削除しました。", flash[:notice]

    post elective_slot_rules_url, params: { elective_slot_rule: { day_of_week: 4, slot_count: 2, slot_duration_minutes: 120 } }
    assert_equal "手術枠ルールを作成しました。", flash[:notice]

    rule = ElectiveSlotRule.last
    patch elective_slot_rule_url(rule), params: { elective_slot_rule: { slot_count: 3 } }
    assert_equal "手術枠ルールを更新しました。", flash[:notice]

    delete elective_slot_rule_url(rule)
    assert_equal "手術枠ルールを削除しました。", flash[:notice]
  end

  # The modal's create response is a turbo-stream/frame, not a redirect.
  test "diagnosis modal creation success message renders in Japanese via turbo stream" do
    sign_in_fresh(users(:japanese_member))

    post diagnoses_url, params: { diagnosis: { name: "Migraine with aura" } },
                         headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml", "Turbo-Frame" => "diagnosis_modal_frame" }

    assert_response :success
    assert_match("診断名を作成しました。", response.body)
  end
end
