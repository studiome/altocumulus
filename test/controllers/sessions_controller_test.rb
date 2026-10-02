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

  test "the login page shows published announcements on a board but not drafts" do
    get login_url

    assert_response :success
    assert_select ".app-board" do
      assert_select ".announcement .app-board-title", text: /Winter schedule notice/
      assert_select ".announcement .app-board-body", text: /year-end closure/
      assert_select ".announcement .app-board-title", text: /Draft: new ward opening/, count: 0
    end
    assert_select ".app-board .alert", 0
  end

  test "an announcement body keeps its line breaks on the board" do
    announcements(:published_one).update!(body: "Line one\nLine two")

    get login_url

    # assert_select squeezes whitespace, so check the raw markup; the board's
    # CSS (white-space: pre-line) is what turns that newline into a line break.
    assert_includes response.body, "Line one\nLine two"
    assert_select ".announcement .app-board-body"
  end

  test "the login page shows no announcement area when none are published" do
    Announcement.update_all(published: false)

    get login_url

    assert_select ".app-board", 0
  end

  test "announcements are still shown when a failed sign-in re-renders the form" do
    post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }

    assert_response :unprocessable_entity
    assert_select ".app-board .announcement .app-board-title", text: /Winter schedule notice/
  end

  test "signs in with correct credentials" do
    sign_in_as(users(:admin))
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end

  test "rejects incorrect password" do
    post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "rejects unknown email" do
    post login_url, params: { session: { login_id: "nobody@example.com", password: "password" } }
    assert_response :unprocessable_entity
  end

  test "rejects inactive user" do
    post login_url, params: { session: { login_id: users(:inactive).login_id, password: "password" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "inactive user with correct password gets the same error message as a failed login" do
    patch locale_path(locale: "en")
    post login_url, params: { session: { login_id: users(:inactive).login_id, password: "password" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_equal "Invalid email or password.", flash[:alert]

    post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }
    assert_response :unprocessable_entity
    assert_equal "Invalid email or password.", flash[:alert]
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
      post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }
    end
    log = AccessLog.last
    assert_equal "login_failed", log.event
  end

  test "records a login_failed access log with no user attribution on wrong password" do
    assert_difference("AccessLog.count", 1) do
      post login_url, params: { session: { login_id: users(:admin).login_id, password: "wrong-password" } }
    end
    log = AccessLog.last
    assert_equal "login_failed", log.event
    assert_nil log.user
  end

  test "records a login_failed access log with no user attribution for an unknown email" do
    assert_difference("AccessLog.count", 1) do
      post login_url, params: { session: { login_id: "nobody@example.com", password: "password" } }
    end
    log = AccessLog.last
    assert_equal "login_failed", log.event
    assert_nil log.user
  end

  test "records a login_failed access log with no user attribution for an inactive user" do
    assert_difference("AccessLog.count", 1) do
      post login_url, params: { session: { login_id: users(:inactive).login_id, password: "password" } }
    end
    log = AccessLog.last
    assert_equal "login_failed", log.event
    assert_nil log.user
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

  # --- config.x.account_identifier switched to "username" ---------------

  test "login form renders a text field instead of an email field in username mode" do
    with_account_identifier("username") do
      get login_url
      assert_response :success
      assert_select "input[type=text][name=?]", "session[login_id]"
      assert_select "input[type=email]", count: 0
    end
  end

  test "signs in with a username login_id in username mode" do
    with_account_identifier("username") do
      user = User.create!(login_id: "taro.yamada", name: "Taro", password: "password", password_confirmation: "password")

      post login_url, params: { session: { login_id: "taro.yamada", password: "password" } }

      assert_redirected_to root_url
      assert_equal user.id, session[:user_id]
    end
  end

  test "invalid credentials alert mentions username in username mode" do
    with_account_identifier("username") do
      patch locale_path(locale: "en")
      post login_url, params: { session: { login_id: "nobody", password: "password" } }
      assert_response :unprocessable_entity
      assert_equal "Invalid username or password.", flash[:alert]
    end
  end
end
