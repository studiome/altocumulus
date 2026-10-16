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

  # --- ledger_columns ---------------------------------------------------

  test "ledger_column_keys defaults to the built-in columns when nothing is configured" do
    config = SiteConfig.from_hash({})
    assert_equal %i[time_slot patient diagnosis_procedure operator_assistant duration_anesthesia category referral_adl],
                 config.ledger_column_keys(:operations_calendar)
    assert_equal config.ledger_column_keys(:operations_calendar), config.ledger_column_keys(:weekly_pdf)
    assert_equal %i[admission_dates patient age_sex diagnosis_procedure_name purpose reservation referral_adl status],
                 config.ledger_column_keys(:examination_calendar)
  end

  test "ledger_columns sets the order per ledger and leaves the others at their default" do
    config = SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => %w[patient time_slot] })
    assert_equal %i[patient time_slot], config.ledger_column_keys(:weekly_pdf)
    assert_equal 7, config.ledger_column_keys(:operations_calendar).size
  end

  test "ledger_columns rejects an unknown ledger" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "nope" => %w[patient] }) }
    assert_match(/ledger_columns has unknown ledger\(s\) nope/, error.message)
  end

  test "ledger_columns rejects an unknown column key" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => %w[patient bogus] }) }
    assert_match(/ledger_columns.weekly_pdf has unknown column\(s\) bogus/, error.message)
  end

  test "ledger_columns rejects a column of the other subject" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => %w[patient purpose] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "examination_calendar" => %w[patient time_slot] }) }
  end

  test "ledger_columns rejects duplicates, empty lists and non-lists" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => %w[patient patient] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => [] }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => "patient" }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => %w[patient]) }
  end

  test "ledger_columns allows the team column only with features.teams" do
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("ledger_columns" => { "weekly_pdf" => %w[patient team] }) }
    assert_match(/team.*features.teams/, error.message)

    config = SiteConfig.from_hash("features" => { "teams" => true }, "ledger_columns" => { "weekly_pdf" => %w[patient team] })
    assert_equal %i[patient team], config.ledger_column_keys(:weekly_pdf)
  end

  test "the example config lays out the richer calendar and PDF columns" do
    config = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_equal %i[admission_dates patient age_sex diagnosis_procedure duration_anesthesia team category reservation referral_adl status],
                 config.ledger_column_keys(:operations_calendar)
    assert_equal %i[time_slot patient age_sex diagnosis_procedure duration_anesthesia team category referral_adl],
                 config.ledger_column_keys(:weekly_pdf)
  end

  # --- weekly_pdf -------------------------------------------------------

  test "weekly_pdf defaults to an 8pt font and no custom title" do
    config = SiteConfig.from_hash({})
    assert_equal 8, config.weekly_pdf_font_size
    assert_nil config.weekly_pdf_title
  end

  test "weekly_pdf accepts a font size from 6 to 10 and a title" do
    config = SiteConfig.from_hash("weekly_pdf" => { "font_size" => 7.5, "title" => "  Weekly Plan  " })
    assert_equal 7.5, config.weekly_pdf_font_size
    assert_equal "Weekly Plan", config.weekly_pdf_title

    assert_equal 6, SiteConfig.from_hash("weekly_pdf" => { "font_size" => 6 }).weekly_pdf_font_size
    assert_equal 10, SiteConfig.from_hash("weekly_pdf" => { "font_size" => 10 }).weekly_pdf_font_size
  end

  test "weekly_pdf treats null and a blank title as no title" do
    assert_nil SiteConfig.from_hash("weekly_pdf" => { "font_size" => 8, "title" => nil }).weekly_pdf_title
    assert_nil SiteConfig.from_hash("weekly_pdf" => { "title" => "   " }).weekly_pdf_title
    assert_equal 8, SiteConfig.from_hash("weekly_pdf" => nil).weekly_pdf_font_size
  end

  test "weekly_pdf rejects font sizes outside 6-10 and non-numbers" do
    [ 5.9, 10.5, 0, -1, "8", true, [ 8 ] ].each do |bad|
      error = assert_raises(SiteConfig::Error, "font_size #{bad.inspect}") { SiteConfig.from_hash("weekly_pdf" => { "font_size" => bad }) }
      assert_match(/weekly_pdf.font_size/, error.message)
    end
  end

  test "weekly_pdf rejects unknown keys, a non-mapping and a non-string title" do
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("weekly_pdf" => { "colour" => "red" }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("weekly_pdf" => "big") }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("weekly_pdf" => { "title" => 5 }) }
    assert_raises(SiteConfig::Error) { SiteConfig.from_hash("weekly_pdf" => { "title" => "x" * 101 }) }
  end

  test "the shipped site.yml and site.example.yml load with their weekly_pdf settings" do
    assert_equal 8, SiteConfig.load(Rails.root.join("config/site.yml")).weekly_pdf_font_size
    assert_nil SiteConfig.load(Rails.root.join("config/site.yml")).weekly_pdf_title
    example = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_equal 8, example.weekly_pdf_font_size
    assert example.weekly_pdf_title.present?
  end

  # --- exports ---------------------------------------------------------

  test "without exports the built-in surgery_list and admission_list apply" do
    definitions = SiteConfig.from_hash({}).export_definitions
    assert_equal %i[surgery_list admission_list], definitions.map(&:key)
    surgery_list, admission_list = definitions
    assert_equal :surgery, surgery_list.subject
    assert_equal :hospitalization, admission_list.subject
    assert_includes surgery_list.fields, :hospital_id
    assert_includes admission_list.fields, :procedure_name
    assert_equal ExportField.keys(:surgery).sort - %i[team team_members], surgery_list.fields.sort
  end

  test "the built-in exports include the team fields with the teams feature" do
    config = SiteConfig.from_hash("features" => { "teams" => true })
    assert_includes config.export_definition(:surgery_list).fields, :team_members
    assert_includes config.export_definition("admission_list").fields, :team
  end

  test "exports are read in file order with an optional label" do
    config = SiteConfig.from_hash("exports" => {
      "ncd_list" => { "subject" => "surgery", "fields" => %w[surgery_date hospital_id], "label" => " NCD " },
      "plain" => { "subject" => "hospitalization", "fields" => [ "admission_date" ] }
    })
    assert_equal %i[ncd_list plain], config.export_definitions.map(&:key)
    ncd = config.export_definition(:ncd_list)
    assert_equal :surgery, ncd.subject
    assert_equal %i[surgery_date hospital_id], ncd.fields
    assert_equal "NCD", ncd.title
    assert_equal "Plain", config.export_definition(:plain).title
    assert_nil config.export_definition(:surgery_list)
  end

  test "an empty exports mapping switches exports off" do
    assert_empty SiteConfig.from_hash("exports" => {}).export_definitions
  end

  test "export validation rejects bad definitions" do
    good = { "subject" => "surgery", "fields" => [ "surgery_date" ] }
    bad = [
      { "Bad-Key" => good },
      { "x" => good.merge("subject" => "patient") },
      { "x" => good.merge("subject" => nil) },
      { "x" => good.merge("fields" => []) },
      { "x" => good.merge("fields" => nil) },
      { "x" => good.merge("fields" => %w[surgery_date surgery_date]) },
      { "x" => good.merge("fields" => [ "procedure_name" ]) },
      { "x" => good.merge("fields" => [ "nope" ]) },
      { "x" => good.merge("fields" => [ 1 ]) },
      { "x" => good.merge("label" => 5) },
      { "x" => good.merge("label" => "y" * 41) },
      { "x" => good.merge("colour" => "red") },
      { "x" => "surgery" },
      [ good ]
    ]
    bad.each do |exports|
      assert_raises(SiteConfig::Error, exports.inspect) { SiteConfig.from_hash("exports" => exports) }
    end
  end

  test "export fields are checked against the export's own subject" do
    error = assert_raises(SiteConfig::Error) do
      SiteConfig.from_hash("exports" => { "x" => { "subject" => "hospitalization", "fields" => [ "surgery_date" ] } })
    end
    assert_match "surgery_date", error.message
  end

  test "team export fields need features.teams" do
    exports = { "x" => { "subject" => "surgery", "fields" => %w[surgery_date team] } }
    error = assert_raises(SiteConfig::Error) { SiteConfig.from_hash("exports" => exports) }
    assert_match "features.teams", error.message
    assert_nothing_raised { SiteConfig.from_hash("exports" => exports, "features" => { "teams" => true }) }
  end

  test "the shipped configs load, the example with an ncd_list export" do
    assert_equal %i[surgery_list admission_list], SiteConfig.load(Rails.root.join("config/site.yml")).export_definitions.map(&:key)
    example = SiteConfig.load(Rails.root.join("config/site.example.yml"))
    assert_includes example.export_definitions.map(&:key), :ncd_list
  end
end
