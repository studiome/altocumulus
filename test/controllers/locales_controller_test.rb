require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_out
  end

  test "signed-in user switching locale persists it on their user record" do
    sign_in_as(users(:member))
    assert_equal "en", users(:member).reload.locale

    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => patients_url }

    assert_equal "ja", users(:member).reload.locale
  end

  test "signed-in user's saved locale is used on a later request" do
    sign_in_as(users(:member))
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => patients_url }

    get patients_url
    assert_response :success
    # Reload picks up the persisted user locale rather than anything cached
    # from the earlier request's around_action.
    assert_equal "ja", users(:member).reload.locale
  end

  test "anonymous visitor switching locale stores it in the session" do
    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => login_url }

    assert_equal "ja", session[:locale]
  end

  test "rejects a locale outside available_locales and leaves it unchanged" do
    sign_in_as(users(:member))

    patch locale_path(locale: "de"), headers: { "HTTP_REFERER" => patients_url }

    assert_equal "en", users(:member).reload.locale
  end

  test "rejects a path-traversal-shaped locale value" do
    sign_in_as(users(:member))

    patch locale_path(locale: "../../etc/passwd"), headers: { "HTTP_REFERER" => patients_url }

    assert_equal "en", users(:member).reload.locale
  end

  test "redirects back to the page the switch was made from" do
    sign_in_as(users(:member))

    patch locale_path(locale: "ja"), headers: { "HTTP_REFERER" => patients_url }

    assert_redirected_to patients_url
  end

  test "falls back to root when there is no referer" do
    sign_in_as(users(:member))

    patch locale_path(locale: "ja")

    assert_redirected_to root_url
  end

  test "locale switch does not require an existing session" do
    patch locale_path(locale: "en"), headers: { "HTTP_REFERER" => login_url }
    assert_response :redirect
  end
end
