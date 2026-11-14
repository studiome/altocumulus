require "test_helper"

class LiveUpdateLayoutTest < ActionDispatch::IntegrationTest
  test "a signed-in page subscribes to the live update stream" do
    get patients_url

    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
    assert_select "meta[name='action-cable-url'][content='/cable']"
  end

  test "the sign-in page does not subscribe" do
    sign_out
    get login_url

    assert_select "turbo-cable-stream-source", count: 0
    assert_select "meta[name='action-cable-url']", count: 0
  end

  test "the policy allows the socket of the same host" do
    get patients_url

    assert_match(/connect-src 'self' ws:\/\/www\.example\.com wss:\/\/www\.example\.com/, response.headers["Content-Security-Policy"])
  end
end
