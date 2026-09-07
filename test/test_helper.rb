ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Shared sign-in/out helpers for request-based tests. System tests override
# sign_in_as with a Capybara-driven version (see application_system_test_case.rb)
# since they run through a real browser session, not the test request stack.
module SignInHelper
  DEFAULT_PASSWORD = "password"

  def sign_in_as(user, password: SignInHelper::DEFAULT_PASSWORD)
    post login_url, params: { session: { email: user.email, password: password } }
  end

  def sign_out
    delete logout_url
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper

  # Every controller now requires a signed-in user. Default to an admin so
  # existing tests keep exercising full functionality; tests that need to
  # verify authentication itself call `sign_out` (or sign in as a different
  # fixture) explicitly.
  setup do
    sign_in_as(users(:admin))
  end
end
