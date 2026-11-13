require "test_helper"
require "open3"
require "json"

# FORCE_SSL is read when the production environment boots, so each case boots
# it in a subprocess (SECRET_KEY_BASE_DUMMY avoids needing real credentials).
class ForceSslConfigurationTest < ActiveSupport::TestCase
  SCRIPT = <<~'RUBY'
    config = Rails.configuration
    exclude = config.ssl_options.dig(:redirect, :exclude)
    puts JSON.generate(
      force_ssl: config.force_ssl,
      assume_ssl: config.assume_ssl,
      up_excluded: exclude&.call(Struct.new(:path).new("/up")),
      prefixed_up_excluded: exclude&.call(Struct.new(:path).new("/newsystem/up")),
      page_excluded: exclude&.call(Struct.new(:path).new("/patients"))
    )
  RUBY

  def production_config(force_ssl)
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1" }
    env["FORCE_SSL"] = force_ssl unless force_ssl.nil?
    out, err, status = Open3.capture3(env, "bin/rails", "runner", SCRIPT, chdir: Rails.root.to_s)
    assert status.success?, err
    JSON.parse(out.lines.last, symbolize_names: true)
  end

  test "SSL is not forced by default so the plain-HTTP deployment keeps working" do
    result = production_config(nil)

    assert_equal false, result[:force_ssl]
    assert_not result[:assume_ssl]
  end

  test "FORCE_SSL=1 forces SSL and keeps the health check reachable over HTTP" do
    result = production_config("1")

    assert_equal true, result[:force_ssl]
    assert_equal true, result[:assume_ssl]
    assert_equal true, result[:up_excluded]
    assert_equal true, result[:prefixed_up_excluded]
    assert_equal false, result[:page_excluded]
  end

  test "FORCE_SSL=0 leaves SSL off" do
    assert_equal false, production_config("0")[:force_ssl]
  end
end
