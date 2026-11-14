require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def session_for(user, **overrides)
    { user_id: user.id, password_fingerprint: user.session_fingerprint, last_seen_at: Time.current.to_i }.merge(overrides)
  end

  test "connects a signed-in user" do
    connect session: session_for(users(:admin))

    assert_equal users(:admin), connection.current_user
  end

  test "rejects a connection without a session" do
    assert_reject_connection { connect session: {} }
  end

  test "rejects a stale password fingerprint" do
    assert_reject_connection { connect session: session_for(users(:admin), password_fingerprint: "stale") }
  end

  test "rejects an inactive user" do
    users(:admin).update_columns(active: false)

    assert_reject_connection { connect session: session_for(users(:admin)) }
  end

  test "rejects a session past the idle timeout" do
    stale = (Rails.application.config.x.session_idle_timeout + 1.minute).ago.to_i

    assert_reject_connection { connect session: session_for(users(:admin), last_seen_at: stale) }
  end

  test "accepts a session within the idle timeout" do
    recent = (Rails.application.config.x.session_idle_timeout - 1.minute).ago.to_i

    connect session: session_for(users(:admin), last_seen_at: recent)
    assert_equal users(:admin), connection.current_user
  end
end
