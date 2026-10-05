require "test_helper"

class DefaultLocaleTest < ActionDispatch::IntegrationTest
  test "a signed-in user with the default locale sees the Japanese navigation" do
    user = User.create!(login_id: "default-locale@example.com", name: "Default Locale",
                        password: SignInHelper::DEFAULT_PASSWORD)
    sign_in_as user

    get root_url
    assert_response :success
    assert_select "header", text: /カレンダー/
  end
end
