require "test_helper"

# Stage 3 (view text externalization), group 4a: the Sessions#new (login)
# screen and its controller flashes. The visitor is anonymous here (never
# signed in), so the Japanese locale has to be set via the session the same
# way LocalesController does it for an anonymous visitor.
class SessionsI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  def switch_to_japanese
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => login_url }
  end

  test "no translation missing on the login screen rendered in Japanese" do
    switch_to_japanese

    get login_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
  end

  test "login screen renders in Japanese" do
    switch_to_japanese

    get login_url

    assert_select "h1", text: "サインイン"
    assert_select "label", text: "メールアドレス"
    assert_select "label", text: "パスワード"
    assert_select "input[type=submit][value=?]", "サインイン"
  end

  test "login screen renders unchanged in English" do
    get login_url

    assert_select "h1", text: "Sign In"
    assert_select "label", text: "Email"
    assert_select "label", text: "Password"
    assert_select "input[type=submit][value=?]", "Sign In"
  end

  test "invalid credentials alert renders in Japanese" do
    switch_to_japanese

    post login_url, params: { session: { email: users(:admin).email, password: "wrong-password" } }

    assert_response :unprocessable_entity
    assert_match "メールアドレスまたはパスワードが正しくありません。", response.body
  end

  test "invalid credentials alert renders unchanged in English" do
    post login_url, params: { session: { email: users(:admin).email, password: "wrong-password" } }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "sign in success flash renders in Japanese" do
    switch_to_japanese

    post login_url, params: { session: { email: users(:japanese_admin).email, password: "password" } }

    assert_redirected_to root_url
    follow_redirect!
    assert_match "サインインしました。", response.body
  end

  test "sign in success flash renders unchanged in English" do
    post login_url, params: { session: { email: users(:admin).email, password: "password" } }

    assert_redirected_to root_url
    follow_redirect!
    assert_match "Signed in successfully.", response.body
  end

  test "sign out flash renders in Japanese" do
    sign_in_as(users(:japanese_admin))

    delete logout_url

    follow_redirect!
    assert_match "サインアウトしました。", response.body
  end

  test "sign out flash renders unchanged in English" do
    sign_in_as(users(:admin))

    delete logout_url

    follow_redirect!
    assert_match "Signed out.", response.body
  end
end
