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
end
