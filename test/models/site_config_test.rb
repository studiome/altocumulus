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

  test "the committed default config seeds no masters" do
    config = SiteConfig.load(Rails.root.join("config/site.yml"))
    SiteConfig::MASTER_KEYS.each { |key| assert_empty config.master_names(key) }
  end

  test "the example config lists masters" do
    config = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_includes config.master_names(:departments), "泌尿器科"
    assert_includes config.master_names("surgery_locations"), "ハイブリッド室"
    assert_equal [ "da Vinci", "hinotori" ], config.master_names(:surgical_devices)
    assert_equal [ "カテ室" ], config.surgery_locations_asking_performing_department
  end

  test "masters are normalized: stripped, de-duplicated, order kept" do
    config = SiteConfig.from_hash("masters" => { "departments" => [ " B ", "A", "B" ] })
    assert_equal %w[B A], config.master_names(:departments)
    assert_empty config.master_names(:surgical_devices)
  end

  test "masters with an unknown key fail fast" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "wards" => [ "x" ] }) }
    assert_match "wards", error.message
  end

  test "masters must be a mapping of lists of non-blank strings" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => [ "x" ]) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "departments" => "x" }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "departments" => [ "x", "" ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "departments" => [ "x", 1 ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "departments" => [ "x", nil ] }) }
  end

  test "a null masters list means empty" do
    assert_empty SiteConfig.from_hash("masters" => { "departments" => nil }).master_names(:departments)
  end

  test "hospitalization_by_purpose loads per-purpose field lists" do
    config = SiteConfig.from_hash("required_fields" => {
      "hospitalization_by_purpose" => { "examination" => %w[procedure_name scheduled_procedure_date], "other" => nil }
    })
    assert_equal %i[procedure_name scheduled_procedure_date], config.required_fields_for_purpose(:examination)
    assert_empty config.required_fields_for_purpose("other")
    assert_empty config.required_fields_for_purpose("surgery")
    assert_empty config.required_fields(:hospitalization)
  end

  test "hospitalization_by_purpose rejects unknown purposes, unknown fields and bad shapes" do
    error = assert_raises(SiteConfig::Error) do
      SiteConfig.from_hash("required_fields" => { "hospitalization_by_purpose" => { "nap" => [ "reason" ] } })
    end
    assert_match "nap", error.message
    error = assert_raises(SiteConfig::Error) do
      SiteConfig.from_hash("required_fields" => { "hospitalization_by_purpose" => { "examination" => [ "nope" ] } })
    end
    assert_match "nope", error.message
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("required_fields" => { "hospitalization_by_purpose" => [ "x" ] }) }
    assert_raises(SiteConfig::Error) do
      SiteConfig.from_hash("required_fields" => { "hospitalization_by_purpose" => { "examination" => "procedure_name" } })
    end
  end

  test "the example config shows a purpose-conditional list" do
    config = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_includes config.required_fields_for_purpose(:examination), :procedure_name
    assert_includes config.required_fields(:hospitalization), :reservation_doctor_id
  end

  test "masters.surgery_locations entries may be a name or a mapping with asks_performing_department" do
    config = SiteConfig.from_hash("masters" => { "surgery_locations" => [ "Ward", { "name" => " Cath Lab ", "asks_performing_department" => true } ] })
    assert_equal [ "Ward", "Cath Lab" ], config.master_names(:surgery_locations)
    assert_equal [ "Cath Lab" ], config.surgery_locations_asking_performing_department
  end

  test "masters mapping entries are validated" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "surgery_locations" => [ { "asks_performing_department" => true } ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "surgery_locations" => [ { "name" => "X", "bogus" => 1 } ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "surgery_locations" => [ { "name" => "X", "asks_performing_department" => "yes" } ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "departments" => [ { "name" => "X" } ] }) }
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

  test "features default to everything off in the committed config" do
    config = SiteConfig.load(Rails.root.join("config/site.yml"))
    assert_not config.teams_enabled?
    assert_not SiteConfig.from_hash({}).teams_enabled?
  end

  test "features.teams turns the teams feature on" do
    assert SiteConfig.from_hash("features" => { "teams" => true }).teams_enabled?
    assert_not SiteConfig.from_hash("features" => { "teams" => false }).teams_enabled?
    assert_not SiteConfig.from_hash("features" => nil).teams_enabled?
  end

  test "features are validated" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("features" => "teams") }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("features" => { "bogus" => true }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("features" => { "teams" => "yes" }) }
  end

  test "team_id may be required only when the teams feature is on" do
    config = SiteConfig.from_hash("features" => { "teams" => true },
                                  "required_fields" => { "hospitalization" => [ "team_id" ], "surgery" => [ "team_id" ],
                                                         "hospitalization_by_purpose" => { "surgery" => [ "team_id" ] } })
    assert_equal [ :team_id ], config.required_fields(:surgery)
    assert_equal [ :team_id ], config.required_fields_for_purpose(:surgery)

    [ { "hospitalization" => [ "team_id" ] }, { "surgery" => [ "team_id" ] },
      { "hospitalization_by_purpose" => { "surgery" => [ "team_id" ] } } ].each do |required|
      error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("required_fields" => required) }
      assert_match(/team_id/, error.message)
      assert_match(/features\.teams/, error.message)
      assert_raises(SiteConfig::Error) { SiteConfig.from_hash("features" => { "teams" => false }, "required_fields" => required) }
    end
  end

  test "masters.teams entries may be a name or a mapping with a color" do
    config = SiteConfig.from_hash("masters" => { "teams" => [ "Plain", { "name" => " Sky ", "color" => "blue" } ] })
    assert_equal [ "Plain", "Sky" ], config.master_names(:teams)
    assert_equal "blue", config.master_option(:teams, "Sky", "color")
    assert_nil config.master_option(:teams, "Plain", "color")
  end

  test "masters.teams colors must be in the palette" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "teams" => [ { "name" => "X", "color" => "magenta" } ] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("masters" => { "teams" => [ { "name" => "X", "bogus" => true } ] }) }
  end

  test "the example config turns teams on and seeds some" do
    config = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert config.teams_enabled?
    assert_equal 3, config.master_names(:teams).size
    assert_equal "blue", config.master_option(:teams, config.master_names(:teams).first, "color")
    assert_includes config.required_fields(:hospitalization), :team_id
  end
end
