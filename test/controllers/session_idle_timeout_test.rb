require "test_helper"

class SessionIdleTimeoutTest < ActionDispatch::IntegrationTest
  test "session stays alive within the idle timeout window" do
    travel(Rails.application.config.x.session_idle_timeout - 1.minute) do
      get patients_url
      assert_response :success
    end
  end

  test "session expires after the idle timeout window and records a timeout access log" do
    travel(Rails.application.config.x.session_idle_timeout + 1.minute) do
      assert_difference("AccessLog.count", 1) do
        get patients_url
      end
      assert_redirected_to login_url
    end

    assert_equal "timeout", AccessLog.last.event
    assert_equal users(:admin), AccessLog.last.user
  end

  test "a live update request does not extend the session" do
    started = session_last_seen { get patients_url }

    travel 5.minutes do
      get patients_url, headers: { "X-Live-Update" => "1" }
      assert_response :success
      assert_equal started, request.session[:last_seen_at]
    end
  end

  test "an ordinary request extends the session" do
    started = session_last_seen { get patients_url }

    travel 5.minutes do
      get patients_url
      assert_operator request.session[:last_seen_at], :>, started
    end
  end

  test "an unattended screen polling live still times out" do
    get patients_url
    last = request.session[:last_seen_at]

    travel(Rails.application.config.x.session_idle_timeout - 1.minute) do
      get patients_url, headers: { "X-Live-Update" => "1" }
      assert_response :success
      assert_equal last, request.session[:last_seen_at]
    end

    travel(Rails.application.config.x.session_idle_timeout + 1.minute) do
      get patients_url, headers: { "X-Live-Update" => "1" }
      assert_redirected_to login_url
    end
  end

  private

  def session_last_seen
    yield
    request.session[:last_seen_at]
  end
end
