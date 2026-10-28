require "test_helper"
require "open3"
require "json"

# Serving the app under a subpath (RAILS_RELATIVE_URL_ROOT) relies on config.ru
# mounting the app with `map` (Rack sets SCRIPT_NAME) and on Rails reading the
# variable at boot. Asset/URL configuration is copied at boot, so changing
# config.relative_url_root inside a running test process would not behave like
# production; each case therefore boots the app in a subprocess.
class RelativeUrlRootTest < ActiveSupport::TestCase
  SCRIPT = <<~'RUBY'
    require "rack/mock"
    app = Rack::Builder.parse_file("config.ru")
    request = Rack::MockRequest.new(app)
    fetch = ->(path) do
      response = request.get(path, "HTTP_HOST" => "localhost")
      { status: response.status, body: response.body.force_encoding("UTF-8") }
    end
    puts JSON.generate(
      prefixed_up: fetch.("/newsystem/up")[:status],
      bare_up: fetch.("/up")[:status],
      prefixed_login: fetch.("/newsystem/login"),
      bare_login: fetch.("/login")
    )
  RUBY

  def boot_and_fetch(relative_url_root)
    env = { "RAILS_ENV" => "test", "RAILS_RELATIVE_URL_ROOT" => relative_url_root }
    out, err, status = Open3.capture3(env, "bin/rails", "runner", SCRIPT, chdir: Rails.root.to_s)
    assert status.success?, err
    JSON.parse(out.lines.last, symbolize_names: true)
  end

  test "health check, assets and favicons are served under the prefix" do
    result = boot_and_fetch("/newsystem")

    assert_equal 200, result[:prefixed_up]
    assert_equal 404, result[:bare_up]

    login = result[:prefixed_login]
    assert_equal 200, login[:status]
    assert_includes login[:body], 'href="/newsystem/icon.png"'
    assert_includes login[:body], 'href="/newsystem/icon.svg"'
    assert_includes login[:body], 'href="/newsystem/assets/'
    assert_no_match(%r{(?:href|src|action)="/(?!newsystem/)}, login[:body])
  end

  test "without a prefix the app is served at the root as before" do
    result = boot_and_fetch("")

    assert_equal 200, result[:bare_up]
    assert_includes result[:bare_login][:body], 'href="/icon.png"'
    assert_includes result[:bare_login][:body], 'href="/assets/'
  end
end
