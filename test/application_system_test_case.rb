require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--headless=new")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1400,1400")
  end

  # System tests drive a real (headless) browser, so signing in has to go
  # through the actual login form rather than posting directly to the
  # sessions controller (see SignInHelper in test_helper.rb for the
  # request-test version).
  def sign_in_as(user, password: SignInHelper::DEFAULT_PASSWORD)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign In"
    # Wait for the post-login redirect to fully land before the test's own
    # navigation runs; otherwise a `visit` immediately after this can race
    # the in-flight redirect from the login form's full-page submit.
    assert_text "Signed in successfully."
  end

  setup do
    sign_in_as(users(:admin))
  end
end
