require "test_helper"

# Covers the i18n foundation laid down for the app: default locale, per-user
# persistence, the pre-login session fallback, rejecting unknown locale
# values, and making sure a request's locale never bleeds into the next one.
# ja.yml's actual translated content (ActiveRecord names/errors, nav text) is
# exercised here too, along with a broad "no translation missing" sweep
# across the app's main screens and detail/new/edit pages.
#
# Final i18n audit note: a handful of screens are deliberately NOT
# duplicated here because a dedicated per-resource file already gives them
# the same "no translation missing" coverage (Japanese-rendered + English-
# unchanged + flash messages), which is the pattern later groups moved to
# rather than growing this one file further:
#   - the login screen (Sessions#new)              -> sessions_i18n_test.rb
#   - audit event show (built dynamically, since
#     test/fixtures/audit_events.yml doesn't exist) -> audit_events_i18n_test.rb
#   - diagnoses/surgery_procedures/holidays/
#     elective_slot_rules new/edit/show             -> master_data_i18n_test.rb
#   - admin users/announcements/admin_notes
#     index/new/edit (using the japanese_admin
#     fixture)                                      -> admin_i18n_test.rb
#   - patients index/show/new/edit,
#     patient_diagnoses, dashboard, searches         -> patients_i18n_test.rb /
#                                                        patient_diagnoses_i18n_test.rb /
#                                                        dashboard_i18n_test.rb /
#                                                        searches_i18n_test.rb
#     (plus the sweep below, which already hits their index/show/new/edit
#     URLs directly)
# Every GET-rendering route in config/routes.rb resolves to at least one
# "no translation missing" assertion somewhere across test/integration/ --
# verified by cross-referencing every named route against the url helpers
# used in this directory's test files.
class LocaleI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "default locale is English" do
    assert_equal :en, I18n.default_locale
  end

  test "a user with locale ja sees the nav rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    get root_url

    assert_response :success
    assert_select "a", text: "患者"
    assert_select "a", text: "手術"
    assert_no_match(/\bPatients\b/, response.body)
  end

  test "a user with locale en sees the nav rendered in English" do
    sign_in_as(users(:member))

    get root_url

    assert_response :success
    assert_select "a", text: "Patients"
    assert_no_match(/患者/, response.body)
  end

  test "I18n.locale does not leak into the next request" do
    sign_in_as(users(:japanese_member))
    get root_url
    assert_select "a", text: "患者"

    sign_out
    sign_in_as(users(:member))
    get root_url
    assert_select "a", text: "Patients"

    # And the ambient locale outside of any request is back to the default,
    # confirming switch_locale's I18n.with_locale block unwound cleanly
    # rather than leaving a bare `I18n.locale =` assignment in place.
    assert_equal I18n.default_locale, I18n.locale
  end

  test "no translation missing on main screens rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    [
      root_url,
      operations_calendar_url,
      patients_url,
      surgeries_url,
      hospitalizations_url,
      diagnoses_url,
      surgery_procedures_url,
      holidays_url,
      elective_slot_rules_url,
      dashboard_url,
      surgery_schedule_url,
      search_url,
      audit_events_url,
      account_url
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  # Stage 2 of the i18n rollout localized the model/helper display strings
  # that these particular show/edit pages render (status_label, outcome/
  # purpose/reservation_status/admin_status labels, laterality labels,
  # length_of_stay_display, ElectiveSlotRule day names and to_s). Covering
  # them by URL (rather than only at the model/helper unit level) catches a
  # missing key that a unit test's stubbed data might not exercise.
  test "no translation missing on hospitalization, surgery, patient, and elective slot rule detail pages rendered in Japanese" do
    sign_in_as(users(:japanese_member))

    [
      patient_url(patients(:one)),
      surgery_url(surgeries(:one)),
      hospitalization_url(hospitalizations(:one)),
      hospitalization_url(hospitalizations(:three)),
      edit_surgery_url(surgeries(:one)),
      edit_patient_url(patients(:one)),
      elective_slot_rule_url(elective_slot_rules(:tuesday)),
      new_patient_url,
      patient_patient_diagnoses_url(patients(:one)),
      patient_patient_diagnosis_url(patients(:one), patient_diagnoses(:appendicitis)),
      new_patient_patient_diagnosis_url(patients(:one)),
      edit_patient_patient_diagnosis_url(patients(:one), patient_diagnoses(:appendicitis)),
      new_hospitalization_url,
      edit_hospitalization_url(hospitalizations(:one)),
      new_surgery_url
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end

  # Stage 3 group 3a (Hospitalizations): the deleted list and its
  # confirm/restore/copy actions are admin-only (see
  # HospitalizationsController#require_admin), so they need an admin whose
  # locale is Japanese rather than the plain japanese_member fixture used
  # above.
  test "no translation missing on the deleted hospitalizations list rendered in Japanese" do
    sign_in_as(users(:japanese_admin))

    get deleted_hospitalizations_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "activerecord attribute names render in Japanese for validation errors" do
    sign_in_as(users(:japanese_member))

    post patients_url, params: { patient: { name: "", hospital_id: "", date_of_birth: "" } }

    assert_response :unprocessable_entity
    assert_match(/氏名/, response.body)
    assert_match(/を入力してください/, response.body)
  end

  test "custom validation error messages render in Japanese" do
    I18n.with_locale(:ja) do
      user = users(:admin)
      User.where(role: "admin").where.not(id: user.id).update_all(active: false)
      user.active = false

      assert_not user.valid?
      assert_includes user.errors[:base], "最後の管理者を削除・降格・無効化することはできません"
    end
  end

  # Stage 3 group 4a: require_login / require_admin live in
  # ApplicationController and run as a before_action shared by every
  # controller, so they cannot use lazy `t(".key")` lookup (the resolved
  # scope would vary with whichever action happened to trigger the
  # redirect) -- they use fixed `common.*` keys instead.
  test "require_login flash renders in Japanese for an anonymous visitor" do
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => login_url }

    get patients_url

    assert_redirected_to login_url
    follow_redirect!
    assert_match "続行するにはサインインしてください。", response.body
  end

  test "require_login flash renders unchanged in English for an anonymous visitor" do
    get patients_url

    assert_redirected_to login_url
    follow_redirect!
    assert_match "Please sign in to continue.", response.body
  end

  test "require_admin flash renders in Japanese for a non-admin user" do
    sign_in_as(users(:japanese_member))

    get admin_users_url

    assert_redirected_to root_url
    follow_redirect!
    assert_match "この操作を行う権限がありません。", response.body
  end

  test "require_admin flash renders unchanged in English for a non-admin user" do
    sign_in_as(users(:member))

    get admin_users_url

    assert_redirected_to root_url
    follow_redirect!
    assert_match "You are not authorized to perform this action.", response.body
  end

  # Stage 3 group 4a: Admin / AuditEvents / Accounts screens.
  test "no translation missing on group 4a screens rendered in Japanese" do
    sign_in_as(users(:japanese_admin))

    [
      admin_users_url,
      admin_announcements_url,
      admin_admin_notes_url,
      audit_events_url,
      account_url
    ].each do |url|
      get url
      assert_response :success, "expected #{url} to render successfully in ja"
      assert_no_match(/[Tt]ranslation missing/, response.body, "translation missing while rendering #{url}")
    end
  end
end
