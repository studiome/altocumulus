require "test_helper"
require_relative "i18n_integration_helper"

# The single "no translation missing" sweep for the Japanese locale. Visits
# every GET-rendering screen of the app (index/show/new/edit pages, deleted
# list, admin screens, case databases, login, calendar window, schedule board,
# dashboard/search states) as a Japanese user and asserts that none of them
# renders a "translation missing" span. The per-screen *_i18n_test.rb files
# only assert what the screens say, not that every key exists.
class I18nTranslationMissingTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  # Fixed window, see OperationsCalendarI18nTest.
  CALENDAR_WINDOW = { start: "2026-03-01", days: 10 }.freeze

  test "screens visible to a regular member render without missing translations" do
    patient = patients(:one)
    surgery = surgeries(:one)
    diagnosis = diagnoses(:appendicitis)
    surgery_procedure = surgery_procedures(:appendectomy)
    holiday = holidays(:national_holiday)
    rule = elective_slot_rules(:tuesday)
    patient_diagnosis = patient_diagnoses(:appendicitis)
    case_database = case_databases(:registry)
    audit_event = AuditEvent.create!(
      auditable_type: "Patient", auditable_id: patient.id,
      action: "update", record_label: patient.to_s,
      change_data: { "name" => [ "Old name", patient.name ] }
    )

    assert_no_translation_missing [
      root_url,
      operations_calendar_url,
      operations_calendar_url(CALENDAR_WINDOW),
      dashboard_url,
      dashboard_url(year: "1999"),
      surgery_schedule_url,
      surgery_schedule_url(week_of: "2026-02-25"),
      surgery_schedule_url(week_of: "2026-03-03"),
      search_url,
      search_url(keyword: "John"),
      search_url(keyword: "zzzznotfound"),
      account_url,
      audit_events_url,
      audit_event_url(audit_event),

      patients_url,
      patient_url(patient),
      new_patient_url,
      edit_patient_url(patient),
      patient_patient_diagnoses_url(patient),
      patient_patient_diagnosis_url(patient, patient_diagnosis),
      new_patient_patient_diagnosis_url(patient),
      edit_patient_patient_diagnosis_url(patient, patient_diagnosis),

      surgeries_url,
      surgery_url(surgery),
      surgery_url(surgeries(:three)),
      new_surgery_url,
      edit_surgery_url(surgery),

      hospitalizations_url,
      hospitalization_url(hospitalizations(:one)),
      hospitalization_url(hospitalizations(:three)),
      new_hospitalization_url,
      edit_hospitalization_url(hospitalizations(:one)),

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
      elective_slot_rule_url(rule),
      edit_elective_slot_rule_url(rule),

      case_databases_url,
      case_database_url(case_database)
    ], as: users(:japanese_member)
  end

  test "the audit log pagination controls render without missing translations" do
    (Pagination::DEFAULT_PER_PAGE + 1).times do |index|
      AuditEvent.create!(
        auditable_type: "Patient", auditable_id: patients(:one).id,
        action: "update", record_label: "Bulk #{index}"
      )
    end

    assert_no_translation_missing audit_events_url, as: users(:japanese_member)
  end

  # Hospitalizations: the deleted list and its confirm/restore/copy actions are
  # admin-only (HospitalizationsController#require_admin), and an admin sees the
  # extra buttons on the regular screens too.
  test "hospitalization screens render without missing translations for an admin" do
    hospitalization = hospitalizations(:one)
    hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnoses(:fracture))
    hospitalizations(:two).discard!

    assert_no_translation_missing [
      hospitalizations_url,
      hospitalization_url(hospitalization),
      new_hospitalization_url,
      edit_hospitalization_url(hospitalization),
      deleted_hospitalizations_url
    ], as: users(:japanese_admin)
  end

  test "the deleted hospitalizations list renders without missing translations when it holds a record" do
    hospitalizations(:one).discard!

    assert_no_translation_missing deleted_hospitalizations_url, as: users(:japanese_admin)
  end

  test "admin screens render without missing translations" do
    assert_no_translation_missing [
      admin_users_url,
      new_admin_user_url,
      edit_admin_user_url(users(:member)),
      admin_announcements_url,
      new_admin_announcement_url,
      edit_admin_announcement_url(announcements(:published_one)),
      admin_admin_notes_url,
      edit_admin_settings_url,
      new_admin_user_import_url,
      audit_events_url,
      account_url
    ], as: users(:japanese_admin)
  end

  test "case database screens render without missing translations for a data manager" do
    data_manager = users(:data_manager)
    data_manager.update!(locale: "ja")
    case_database = case_databases(:registry)

    assert_no_translation_missing [
      case_databases_url,
      new_case_database_url,
      case_database_url(case_database),
      edit_case_database_url(case_database),
      new_case_database_field_url(case_database),
      edit_case_database_field_url(case_database, case_database_fields(:notes)),
      new_case_database_entry_url(case_database),
      edit_case_database_entry_url(case_database, case_database_entries(:one))
    ], as: data_manager
  end

  test "the login screen renders without missing translations when signed out" do
    sign_out
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => login_url }

    get login_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end
end
