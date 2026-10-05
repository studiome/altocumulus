require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the Sessions#new (login) screen and its controller flashes. The
# visitor is anonymous here (never signed in), so the locale is chosen via the
# session the same way LocalesController does it for an anonymous visitor.
# The English "Invalid email or password." alert is already asserted by
# sessions_controller_test.rb ("inactive user with correct password gets the
# same error message..."), so only the Japanese alert is checked here.
class SessionsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup { sign_out }

  def switch_to(locale)
    patch locale_path(locale: locale), headers: { "HTTP_REFERER" => login_url }
  end

  test "login screen renders in Japanese by default and in English once switched" do
    get login_url
    assert_select "h1", text: "サインイン"

    switch_to "ja"
    get login_url
    assert_select "h1", text: "サインイン"
    assert_select "label", text: "メールアドレス"
    assert_select "label", text: "パスワード"
    assert_select "input[type=submit][value=?]", "サインイン"

    switch_to "en"
    get login_url
    assert_select "h1", text: "Sign In"
    assert_select "label", text: "Email"
    assert_select "label", text: "Password"
    assert_select "input[type=submit][value=?]", "Sign In"
  end

  test "invalid credentials alert renders in Japanese" do
    switch_to "ja"

    post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }

    assert_response :unprocessable_entity
    assert_match "メールアドレスまたはパスワードが正しくありません。", response.body
  end

  test "sign in and sign out flashes render in Japanese and English" do
    switch_to "ja"
    post login_url, params: { session: { login_id: users(:japanese_admin).login_id, password: "password" } }
    assert_redirected_to root_url
    follow_redirect!
    assert_match "サインインしました。", response.body

    delete logout_url
    follow_redirect!
    assert_match "サインアウトしました。", response.body

    switch_to "en"
    post login_url, params: { session: { login_id: users(:admin).login_id, password: "password" } }
    assert_redirected_to root_url
    follow_redirect!
    assert_match "Signed in successfully.", response.body

    delete logout_url
    follow_redirect!
    assert_match "Signed out.", response.body
  end
end
