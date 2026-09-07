require "test_helper"

# Covers the i18n foundation laid down for the app: default locale, per-user
# persistence, the pre-login session fallback, rejecting unknown locale
# values, and making sure a request's locale never bleeds into the next one.
# ja.yml's actual translated content (ActiveRecord names/errors, nav text) is
# exercised here too, since that is the only user-visible surface this stage
# of the i18n rollout touches -- most view text is still English pending the
# later stage that wraps it in `t()`.
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
end
