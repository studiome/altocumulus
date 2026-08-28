require "test_helper"
require "socket"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Inside the Dev Container the browser lives in the companion "selenium"
  # service, so Capybara has to serve the app on an address that container can
  # reach. Everywhere else (CI, plain local runs) Selenium Manager takes care of
  # launching a local headless Chrome.
  REMOTE_OPTIONS =
    if (selenium_host = ENV["SELENIUM_HOST"]).present?
      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = ENV.fetch("CAPYBARA_SERVER_PORT", "45678").to_i
      Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}:#{Capybara.server_port}"

      # The Capybara server above is bound to one fixed host/port, and the
      # companion "selenium" service only offers a single browser session.
      # Parallel test workers would race for both, so a losing worker's
      # `visit` can hang until it hits Net::ReadTimeout. Run system tests
      # serially whenever we're driving that shared remote browser.
      parallelize(workers: 1)

      { browser: :remote, url: "http://#{selenium_host}:4444" }
    else
      {}
    end

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: REMOTE_OPTIONS do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--headless=new")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1400,1400")
  end
end
