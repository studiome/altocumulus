require "test_helper"

class AccessLogTest < ActiveSupport::TestCase
  test "valid with a known event" do
    log = AccessLog.new(user: users(:admin), event: "login")
    assert log.valid?
  end

  test "user is optional" do
    log = AccessLog.new(user: nil, event: "login_failed")
    assert log.valid?
  end

  test "requires a known event" do
    log = AccessLog.new(event: "bogus")
    assert_not log.valid?
    assert_includes log.errors[:event], "is not included in the list"
  end

  test "requires an event" do
    log = AccessLog.new(event: nil)
    assert_not log.valid?
    assert_includes log.errors[:event], "can't be blank"
  end
end
