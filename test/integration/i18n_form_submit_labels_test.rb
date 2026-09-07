require "test_helper"

# Cross-cutting i18n gap: `helpers.submit`. A bare `form.submit` (no explicit
# label) falls back to Rails' own English template ("Create %{model}"),
# which mixes English and Japanese once `model_name.human` is Japanese (e.g.
# "Create 患者"). Exercised across all 9 forms in this app that call
# `form.submit` without an explicit label (patients, diagnoses,
# surgery_procedures, holidays, elective_slot_rules, hospitalizations,
# surgeries, admin/users, admin/announcements).
class I18nFormSubmitLabelsTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "all 9 form submit buttons render in Japanese for a new record" do
    sign_in_as(users(:japanese_admin))

    {
      new_patient_url => "患者を作成",
      new_diagnosis_url => "診断名を作成",
      new_surgery_procedure_url => "術式を作成",
      new_holiday_url => "休日を作成",
      new_elective_slot_rule_url => "手術枠ルールを作成",
      new_hospitalization_url => "入院を作成",
      new_surgery_url => "手術を作成",
      new_admin_user_url => "利用者を作成",
      new_admin_announcement_url => "お知らせを作成"
    }.each do |url, expected|
      get url
      assert_response :success
      assert_select "input[type=submit][value=?]", expected
    end
  end

  test "all 9 form submit buttons render in Japanese for an existing record" do
    sign_in_as(users(:japanese_admin))

    {
      edit_patient_url(patients(:one)) => "患者を更新",
      edit_diagnosis_url(diagnoses(:appendicitis)) => "診断名を更新",
      edit_surgery_procedure_url(surgery_procedures(:appendectomy)) => "術式を更新",
      edit_holiday_url(holidays(:national_holiday)) => "休日を更新",
      edit_elective_slot_rule_url(elective_slot_rules(:tuesday)) => "手術枠ルールを更新",
      edit_hospitalization_url(hospitalizations(:one)) => "入院を更新",
      edit_surgery_url(surgeries(:one)) => "手術を更新",
      edit_admin_user_url(users(:member)) => "利用者を更新",
      edit_admin_announcement_url(announcements(:published_one)) => "お知らせを更新"
    }.each do |url, expected|
      get url
      assert_response :success
      assert_select "input[type=submit][value=?]", expected
    end
  end

  test "form submit buttons render unchanged in English" do
    sign_in_as(users(:admin))

    get new_patient_url
    assert_select "input[type=submit][value=?]", "Create Patient"

    get edit_patient_url(patients(:one))
    assert_select "input[type=submit][value=?]", "Update Patient"

    get new_admin_user_url
    assert_select "input[type=submit][value=?]", "Create User"
  end
end
