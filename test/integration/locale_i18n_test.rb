require "test_helper"
require_relative "i18n_integration_helper"

# i18n foundation of the app: default locale, per-user persistence, the
# pre-login session fallback, and making sure a request's locale never bleeds
# into the next one. ja.yml's translated ActiveRecord names/errors and the
# shared before_action flashes (require_login / require_admin) are exercised
# here too. The broad "no translation missing" sweep over every screen lives in
# i18n_translation_missing_test.rb.
class LocaleI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup { sign_out }

  test "default locale is English" do
    assert_equal :en, I18n.default_locale
  end

  test "an anonymous visitor who has not picked a locale sees Japanese" do
    get patients_url

    follow_redirect!
    assert_match "続行するにはサインインしてください。", response.body
  end

  test "the nav renders in the user's locale and I18n.locale does not leak into the next request" do
    get_as users(:japanese_member), root_url
    assert_response :success
    assert_select "a", text: "患者"
    assert_select "a", text: "手術"
    assert_no_match(/\bPatients\b/, response.body)

    get_as users(:member), root_url
    assert_response :success
    assert_select "a", text: "Patients"
    assert_no_match(/患者/, response.body)

    # The ambient locale outside of any request is back to the default,
    # confirming switch_locale's I18n.with_locale block unwound cleanly rather
    # than leaving a bare `I18n.locale =` assignment in place.
    assert_equal I18n.default_locale, I18n.locale
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
      User.admins.where.not(id: user.id).update_all(active: false)
      user.active = false

      assert_not user.valid?
      assert_includes user.errors[:base], "最後の管理者を削除・降格・無効化することはできません"
    end
  end

  # require_login / require_admin run as a before_action shared by every
  # controller, so they cannot use lazy `t(".key")` lookup (the resolved scope
  # would vary with whichever action triggered the redirect) -- they use fixed
  # `common.*` keys instead.
  test "require_login flash renders in Japanese and English for an anonymous visitor" do
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => login_url }

    get patients_url

    assert_redirected_to login_url
    follow_redirect!
    assert_match "続行するにはサインインしてください。", response.body

    patch locale_path(locale: "en"), headers: { "HTTP_REFERER" => login_url }

    get patients_url

    assert_redirected_to login_url
    follow_redirect!
    assert_match "Please sign in to continue.", response.body
  end

  test "require_admin flash renders in Japanese and English for a non-admin user" do
    get_as users(:japanese_member), admin_users_url

    assert_redirected_to root_url
    follow_redirect!
    assert_match "この操作を行う権限がありません。", response.body

    get_as users(:member), admin_users_url

    assert_redirected_to root_url
    follow_redirect!
    assert_match "You are not authorized to perform this action.", response.body
  end
end
