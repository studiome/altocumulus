require "test_helper"
require "tempfile"

class SiteConfigTest < ActiveSupport::TestCase
  def write_yaml(content)
    file = Tempfile.new([ "site", ".yml" ])
    file.write(content)
    file.flush
    (@tempfiles ||= []) << file
    file.path
  end

  test "the committed default config adds no restrictions" do
    config = SiteConfig.load(Rails.root.join("config/site.yml"))
    assert_empty config.required_fields(:hospitalization)
    assert_empty config.required_fields(:surgery)
    assert_nil config.hospital_id_format
    assert_nil config.hospital_id_format_hint
  end

  test "the example config is valid" do
    config = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_includes config.required_fields(:hospitalization), :referred_from
    assert_kind_of Regexp, config.hospital_id_format
  end

  test "an empty file is valid and means defaults" do
    config = SiteConfig.load(write_yaml(""))
    assert_empty config.required_fields(:surgery)
  end

  test "loads required fields and patient format" do
    path = write_yaml(<<~YAML)
      required_fields:
        hospitalization: [referred_from]
        surgery: [operator_name, duration_hours]
      patient:
        hospital_id_format: '\\A\\d{8}\\z'
        hospital_id_format_hint: "8 digits"
    YAML
    config = SiteConfig.load(path)
    assert_equal [ :referred_from ], config.required_fields(:hospitalization)
    assert_equal [ :operator_name, :duration_hours ], config.required_fields("surgery")
    assert_match config.hospital_id_format, "12345678"
    assert_equal "8 digits", config.hospital_id_format_hint
  end

  test "SITE_CONFIG_PATH wins over the committed file" do
    path = write_yaml("required_fields:\n  surgery: [operator_name]\n")
    config = SiteConfig.load_default(env: { "SITE_CONFIG_PATH" => path })
    assert_equal [ :operator_name ], config.required_fields(:surgery)
  end

  test "falls back to config/site.yml when SITE_CONFIG_PATH is unset or blank" do
    assert_empty SiteConfig.load_default(env: {}).required_fields(:surgery)
    assert_empty SiteConfig.load_default(env: { "SITE_CONFIG_PATH" => "" }).required_fields(:surgery)
  end

  test "a missing SITE_CONFIG_PATH file fails fast" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.load_default(env: { "SITE_CONFIG_PATH" => "/nonexistent/site.yml" }) }
    assert_match "/nonexistent/site.yml", error.message
  end

  test "malformed YAML fails fast" do
    assert_raises(SiteConfig::Error) { SiteConfig.load(write_yaml("required_fields: [unterminated")) }
  end

  test "a non-mapping document fails fast" do
    assert_raises(SiteConfig::Error) { SiteConfig.load(write_yaml("- a\n- b\n")) }
  end

  test "unknown top-level keys fail fast" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("bogus" => 1) }
    assert_match "bogus", error.message
  end

  test "unknown models and unknown fields fail fast" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("required_fields" => { "nope" => [ "x" ] }) }
    assert_match "nope", error.message
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("required_fields" => { "surgery" => [ "not_a_column" ] }) }
    assert_match "not_a_column", error.message
  end

  test "required_fields must be lists of strings" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("required_fields" => { "surgery" => "operator_name" }) }
  end

  test "unknown patient keys fail fast" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("patient" => { "bogus" => 1 }) }
  end

  test "an uncompilable hospital_id_format fails fast" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("patient" => { "hospital_id_format" => "(" }) }
    assert_match "hospital_id_format", error.message
  end

  test "with swaps the current config and restores it" do
    original = SiteConfig.current
    with_site_config("required_fields" => { "surgery" => [ "operator_name" ] }) do
      assert_equal [ :operator_name ], SiteConfig.current.required_fields(:surgery)
    end
    assert_same original, SiteConfig.current
  end

  test "with restores the config even when the block raises" do
    original = SiteConfig.current
    assert_raises(RuntimeError) { with_site_config({}) { raise "boom" } }
    assert_same original, SiteConfig.current
  end
end
