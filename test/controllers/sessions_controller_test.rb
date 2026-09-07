require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_out
  end

  test "unauthenticated visitor is redirected to login" do
    get patients_url
    assert_redirected_to login_url
  end

  test "getting the login page does not require authentication" do
    get login_url
    assert_response :success
  end

  test "signs in with correct credentials" do
    sign_in_as(users(:admin))
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end

  test "rejects incorrect password" do
    post login_url, params: { session: { email: users(:admin).email, password: "wrong-password" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "rejects unknown email" do
    post login_url, params: { session: { email: "nobody@example.com", password: "password" } }
    assert_response :unprocessable_entity
  end

  test "rejects inactive user" do
    post login_url, params: { session: { email: users(:inactive).email, password: "password" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "records a login access log on success" do
    assert_difference("AccessLog.count", 1) do
      sign_in_as(users(:admin))
    end
    log = AccessLog.last
    assert_equal "login", log.event
    assert_equal users(:admin), log.user
  end

  test "records a login_failed access log on failure" do
    assert_difference("AccessLog.count", 1) do
      post login_url, params: { session: { email: users(:admin).email, password: "wrong-password" } }
    end
    log = AccessLog.last
    assert_equal "login_failed", log.event
  end

  test "logs out and records a logout access log" do
    sign_in_as(users(:admin))

    assert_difference("AccessLog.count", 1) do
      delete logout_url
    end
    assert_equal "logout", AccessLog.last.event
    assert_redirected_to login_url

    get patients_url
    assert_redirected_to login_url
  end
end
