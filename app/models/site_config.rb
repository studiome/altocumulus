# Deploy-time site configuration: everything that differs from one hospital
# (installation) to the next but is NOT worth a settings screen, such as which
# form fields must be filled in or what a patient ID looks like.
#
# Where it comes from, in order:
#   1. the YAML file at ENV["SITE_CONFIG_PATH"] (production mounts one there
#      through a Kamal volume, see config/deploy.yml), otherwise
#   2. config/site.yml committed in the repo (a neutral default that keeps the
#      app's stock behavior).
#
# It is read once at boot (config/initializers/site_config.rb) and a bad file
# raises SiteConfig::Error so a deploy fails immediately instead of failing
# on the first save. Adding a new top-level key means adding one entry to
# SCHEMA (a validator returning the normalized value) and one reader method.
class SiteConfig
  class Error < StandardError; end

  DEFAULT_PATH = "config/site.yml"

  # Models whose fields can be listed under required_fields, keyed by the
  # name used in the YAML file.
  REQUIRED_FIELD_MODELS = {
    "hospitalization" => "Hospitalization",
    "surgery" => "Surgery"
  }.freeze

  # required_fields also takes hospitalization_by_purpose: purpose =>
  # [field, ...], fields required only for hospitalizations of that purpose.
  BY_PURPOSE_KEY = "hospitalization_by_purpose".freeze

  PATIENT_KEYS = %w[hospital_id_format hospital_id_format_hint].freeze

  # Keys of the masters section: the names a deployment wants present in the
  # admin-editable master tables (see SiteMasterSeeder, `site:seed_masters`).
  MASTER_KEYS = %w[departments surgery_locations surgical_devices teams].freeze

  # Masters whose entries may be a mapping ({name: ..., <option>: ...}) instead
  # of a plain name, with the options each accepts.
  MASTER_ENTRY_OPTIONS = {
    "surgery_locations" => %w[asks_performing_department],
    "teams" => %w[color]
  }.freeze

  # Optional features a site can switch on (features.<key>: true). Everything
  # is off by default, which keeps the stock behavior.
  FEATURE_KEYS = %w[teams].freeze

  # Required-field name that only makes sense with the teams feature on.
  TEAM_FIELD = "team_id".freeze

  # weekly_pdf: the weekly surgery schedule PDF's look.
  WEEKLY_PDF_KEYS = %w[font_size title].freeze
  WEEKLY_PDF_FONT_SIZES = (6..10).freeze
  WEEKLY_PDF_DEFAULT_FONT_SIZE = 8
  WEEKLY_PDF_TITLE_MAX = 100

  # exports: named CSV exports (see ExportDefinition, ExportField).
  EXPORT_KEYS = %w[subject fields label].freeze
  EXPORT_LABEL_MAX = 40

  # top-level key => validator method (receives the raw value, returns the
  # normalized one, raises Error).
  SCHEMA = {
    "required_fields" => :normalize_required_fields,
    "patient" => :normalize_patient,
    "features" => :normalize_features,
    "masters" => :normalize_masters,
    "ledger_columns" => :normalize_ledger_columns,
    "weekly_pdf" => :normalize_weekly_pdf,
    "exports" => :normalize_exports
  }.freeze

  class << self
    def current
      @current ||= load_default
    end

    def current=(config)
      @current = config
    end

    def reset!
      @current = nil
    end

    # Whether the schema is behind the migrations on disk (also a seam for tests).
    def pending_migrations?
      ActiveRecord::Base.connection_pool.migration_context.needs_migration?
    end

    # Temporarily swap the current config (tests). Accepts a SiteConfig or a
    # hash with the shape of site.yml.
    def with(config)
      config = from_hash(config) unless config.is_a?(SiteConfig)
      original = @current
      @current = config
      yield
    ensure
      @current = original
    end

    def load_default(env: ENV)
      path = env["SITE_CONFIG_PATH"].presence
      if path
        raise Error, "SITE_CONFIG_PATH points to a file that does not exist: #{path}" unless File.file?(path)
        load(path)
      else
        load(Rails.root.join(DEFAULT_PATH))
      end
    end

    def load(path)
      data = begin
        YAML.safe_load_file(path.to_s, aliases: false)
      rescue Psych::Exception, SystemCallError => e
        raise Error, "Cannot read site config #{path}: #{e.message}"
      end
      from_hash(data || {}, path.to_s)
    end

    def from_hash(hash, source = "site config")
      hash = (hash || {}).deep_stringify_keys
      new(hash, source)
    rescue NoMethodError
      raise Error, "#{source}: must be a mapping of settings"
    end
  end

  attr_reader :source

  def initialize(hash, source = "site config")
    raise Error, "#{source}: must be a mapping of settings" unless hash.is_a?(Hash)

    @source = source
    unknown = hash.keys - SCHEMA.keys
    raise Error, "#{source}: unknown key(s) #{unknown.join(', ')} (known: #{SCHEMA.keys.join(', ')})" if unknown.any?

    @values = SCHEMA.each_with_object({}) do |(key, validator), values|
      values[key] = send(validator, hash[key])
    end
    reject_team_fields_without_teams_feature!
    reject_team_column_without_teams_feature!
    reject_team_export_fields_without_teams_feature!
    @values.freeze
  end

  # features.teams: whether care teams are used (nav, selects, displays).
  def teams_enabled?
    @values.fetch("features").fetch("teams", false)
  end

  # Attribute names (symbols) that must be present for the given model
  # ("hospitalization" / "surgery"), beyond what the model always requires.
  def required_fields(model)
    @values.fetch("required_fields").fetch(model.to_s, [])
  end

  # Attribute names (symbols) required only for hospitalizations of the given
  # purpose (required_fields.hospitalization_by_purpose).
  def required_fields_for_purpose(purpose)
    @values.fetch("required_fields").fetch(BY_PURPOSE_KEY, {}).fetch(purpose.to_s, [])
  end

  def hospital_id_format
    @values.fetch("patient")[:hospital_id_format]
  end

  def hospital_id_format_hint
    @values.fetch("patient")[:hospital_id_format_hint]
  end

  # Names configured under masters.<key> (departments / surgery_locations /
  # surgical_devices), in file order; empty when none.
  def master_names(key)
    @values.fetch("masters").fetch(key.to_s, [])
  end

  # Names of the surgery locations the site flagged asks_performing_department
  # (see SiteMasterSeeder).
  def surgery_locations_asking_performing_department
    @master_flags.fetch("surgery_locations", {}).select { |_name, flags| flags["asks_performing_department"] }.keys
  end

  # The value of an option given on a masters entry (e.g. a team's color), or
  # nil when the entry did not set it.
  def master_option(key, name, option)
    @master_flags.fetch(key.to_s, {}).fetch(name.to_s, {})[option.to_s]
  end

  # Keys (symbols) of the columns the ledger shows, in order: the configured
  # list, else the ledger's built-in default (see LedgerColumn::LEDGERS).
  def ledger_column_keys(ledger)
    @values.fetch("ledger_columns").fetch(ledger.to_s) { LedgerColumn.default_keys(ledger) }
  end

  # The PDF's starting font size in points (it may shrink a few steps to fit
  # the columns, see LedgerColumnFitting).
  def weekly_pdf_font_size
    @values.fetch("weekly_pdf").fetch(:font_size, WEEKLY_PDF_DEFAULT_FONT_SIZE)
  end

  # The title the site wants on the PDF instead of the translated default, or nil.
  def weekly_pdf_title
    @values.fetch("weekly_pdf")[:title]
  end

  # The CSV exports on offer (ExportDefinition), in file order: the configured
  # ones, or the built-in surgery_list / admission_list when `exports` is
  # omitted (an explicit empty mapping switches exports off).
  def export_definitions
    configured = @values.fetch("exports")
    return ExportDefinition.defaults(teams_enabled: teams_enabled?) if configured.nil?

    configured.values
  end

  def export_definition(key)
    export_definitions.find { |definition| definition.key.to_s == key.to_s }
  end

  private

    def reject_team_fields_without_teams_feature!
      return if teams_enabled?

      required = @values.fetch("required_fields")
      lists = required.except(BY_PURPOSE_KEY).values + required.fetch(BY_PURPOSE_KEY, {}).values
      return unless lists.any? { |fields| fields.include?(TEAM_FIELD.to_sym) }

      raise Error, "#{source}: required_fields lists #{TEAM_FIELD}, which needs features.teams to be true"
    end

    def reject_team_column_without_teams_feature!
      return if teams_enabled?

      @values.fetch("ledger_columns").each do |ledger, keys|
        next unless keys.include?(LedgerColumn::TEAM_COLUMN)

        raise Error, "#{source}: ledger_columns.#{ledger} lists #{LedgerColumn::TEAM_COLUMN}, which needs features.teams to be true"
      end
    end

    def reject_team_export_fields_without_teams_feature!
      return if teams_enabled?

      (@values.fetch("exports") || {}).each_value do |definition|
        team_fields = definition.fields.select { |key| ExportField.find(definition.subject, key).teams? }
        next if team_fields.empty?

        raise Error, "#{source}: exports.#{definition.key} lists #{team_fields.join(', ')}, which needs features.teams to be true"
      end
    end

    def normalize_features(value)
      return {}.freeze if value.nil?
      raise Error, "#{source}: features must be a mapping of feature => true/false" unless value.is_a?(Hash)

      unknown = value.keys - FEATURE_KEYS
      raise Error, "#{source}: features has unknown key(s) #{unknown.join(', ')} (known: #{FEATURE_KEYS.join(', ')})" if unknown.any?

      unless value.values.all? { |flag| flag == true || flag == false }
        raise Error, "#{source}: features values must be true or false"
      end

      value.freeze
    end

    def normalize_required_fields(value)
      return {} if value.nil?
      raise Error, "#{source}: required_fields must be a mapping of model => [field, ...]" unless value.is_a?(Hash)

      known = REQUIRED_FIELD_MODELS.keys + [ BY_PURPOSE_KEY ]
      unknown_models = value.keys - known
      if unknown_models.any?
        raise Error, "#{source}: required_fields has unknown model(s) #{unknown_models.join(', ')} (known: #{known.join(', ')})"
      end

      value.to_h do |model, fields|
        next [ model, normalize_by_purpose(fields) ] if model == BY_PURPOSE_KEY

        [ model, normalize_field_list("required_fields.#{model}", model, fields) ]
      end.freeze
    end

    def normalize_by_purpose(value)
      return {}.freeze if value.nil?
      unless value.is_a?(Hash)
        raise Error, "#{source}: required_fields.#{BY_PURPOSE_KEY} must be a mapping of purpose => [field, ...]"
      end

      unknown = value.keys - Hospitalization::PURPOSE_KEYS
      if unknown.any?
        raise Error, "#{source}: required_fields.#{BY_PURPOSE_KEY} has unknown purpose(s) #{unknown.join(', ')} (known: #{Hospitalization::PURPOSE_KEYS.join(', ')})"
      end

      value.to_h do |purpose, fields|
        [ purpose, normalize_field_list("required_fields.#{BY_PURPOSE_KEY}.#{purpose}", "hospitalization", fields) ]
      end.freeze
    end

    def normalize_field_list(label, model, fields)
      fields = [] if fields.nil?
      raise Error, "#{source}: #{label} must be a list of field names" unless fields.is_a?(Array) && fields.all?(String)

      validate_field_names!(label, model, fields)
      fields.map(&:to_sym).uniq.freeze
    end

    # Field names are checked against the model's real attribute names so a
    # typo fails the deploy instead of silently never being required. The check
    # is skipped, rather than failing the boot for an unrelated reason, when the
    # database is not reachable yet (assets:precompile, db:create) or when
    # migrations are pending: the container entrypoint runs db:prepare, which
    # boots the app before migrating, and a config may name a column that very
    # migration adds. The server's own boot after the migration checks for real.
    def validate_field_names!(label, model, fields)
      return if self.class.pending_migrations?

      attribute_names = REQUIRED_FIELD_MODELS.fetch(model).constantize.attribute_names
      unknown = fields - attribute_names
      return if unknown.empty?

      raise Error, "#{source}: #{label} has unknown field(s) #{unknown.join(', ')}"
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    # ledger => [column key, ...]. Each list is checked against the columns
    # that exist for the ledger's kind of record, so a typo (or a column of the
    # wrong ledger) fails the deploy instead of rendering nothing.
    def normalize_ledger_columns(value)
      return {}.freeze if value.nil?
      raise Error, "#{source}: ledger_columns must be a mapping of ledger => [column, ...]" unless value.is_a?(Hash)

      ledgers = LedgerColumn.ledger_names.map(&:to_s)
      unknown = value.keys - ledgers
      raise Error, "#{source}: ledger_columns has unknown ledger(s) #{unknown.join(', ')} (known: #{ledgers.join(', ')})" if unknown.any?

      value.to_h { |ledger, keys| [ ledger, normalize_ledger_column_list(ledger, keys) ] }.freeze
    end

    def normalize_ledger_column_list(ledger, keys)
      label = "ledger_columns.#{ledger}"
      raise Error, "#{source}: #{label} must be a non-empty list of column keys" unless keys.is_a?(Array) && keys.any? && keys.all?(String)
      raise Error, "#{source}: #{label} lists a column more than once" unless keys.uniq.size == keys.size

      known = LedgerColumn.keys(LedgerColumn.subject_for(ledger)).map(&:to_s)
      unknown = keys - known
      raise Error, "#{source}: #{label} has unknown column(s) #{unknown.join(', ')} (known: #{known.join(', ')})" if unknown.any?

      keys.map(&:to_sym).freeze
    end

    def normalize_weekly_pdf(value)
      return {}.freeze if value.nil?
      raise Error, "#{source}: weekly_pdf must be a mapping" unless value.is_a?(Hash)

      unknown = value.keys - WEEKLY_PDF_KEYS
      raise Error, "#{source}: weekly_pdf has unknown key(s) #{unknown.join(', ')} (known: #{WEEKLY_PDF_KEYS.join(', ')})" if unknown.any?

      result = {}
      size = value["font_size"]
      unless size.nil?
        unless size.is_a?(Numeric) && WEEKLY_PDF_FONT_SIZES.cover?(size)
          raise Error, "#{source}: weekly_pdf.font_size must be a number from #{WEEKLY_PDF_FONT_SIZES.first} to #{WEEKLY_PDF_FONT_SIZES.last}"
        end
        result[:font_size] = size
      end

      title = value["title"]
      unless title.nil?
        raise Error, "#{source}: weekly_pdf.title must be a string or null" unless title.is_a?(String)
        raise Error, "#{source}: weekly_pdf.title must be at most #{WEEKLY_PDF_TITLE_MAX} characters" if title.strip.length > WEEKLY_PDF_TITLE_MAX

        result[:title] = title.strip if title.strip.present?
      end
      result.freeze
    end

    # key => ExportDefinition, or nil when `exports` is omitted (the built-in
    # defaults then apply, see #export_definitions).
    def normalize_exports(value)
      return nil if value.nil?
      raise Error, "#{source}: exports must be a mapping of export name => {subject:, fields:}" unless value.is_a?(Hash)

      value.to_h do |key, definition|
        [ key, normalize_export(key, definition) ]
      end.freeze
    end

    def normalize_export(key, definition)
      label = "exports.#{key}"
      unless key.is_a?(String) && key.match?(ExportDefinition::KEY_FORMAT)
        raise Error, "#{source}: #{label}: the export name must match #{ExportDefinition::KEY_FORMAT.source} (lowercase letters, digits, underscore)"
      end
      raise Error, "#{source}: #{label} must be a mapping with subject and fields" unless definition.is_a?(Hash)

      unknown = definition.keys - EXPORT_KEYS
      raise Error, "#{source}: #{label} has unknown key(s) #{unknown.join(', ')} (known: #{EXPORT_KEYS.join(', ')})" if unknown.any?

      subjects = ExportField::SUBJECTS.map(&:to_s)
      subject = definition["subject"]
      raise Error, "#{source}: #{label}.subject must be one of #{subjects.join(', ')}" unless subjects.include?(subject)

      ExportDefinition.new(key: key.to_sym, subject: subject.to_sym, fields: normalize_export_fields(label, subject, definition["fields"]),
                           label: normalize_export_label(label, definition["label"]))
    end

    def normalize_export_fields(label, subject, fields)
      raise Error, "#{source}: #{label}.fields must be a non-empty list of field keys" unless fields.is_a?(Array) && fields.any? && fields.all?(String)
      raise Error, "#{source}: #{label}.fields lists a field more than once" unless fields.uniq.size == fields.size

      known = ExportField.keys(subject).map(&:to_s)
      unknown = fields - known
      raise Error, "#{source}: #{label}.fields has unknown field(s) #{unknown.join(', ')} (known for #{subject}: #{known.join(', ')})" if unknown.any?

      fields.map(&:to_sym).freeze
    end

    def normalize_export_label(label, value)
      return nil if value.nil?
      raise Error, "#{source}: #{label}.label must be a string" unless value.is_a?(String)
      raise Error, "#{source}: #{label}.label must be at most #{EXPORT_LABEL_MAX} characters" if value.strip.length > EXPORT_LABEL_MAX

      value.strip.presence
    end

    def normalize_patient(value)
      return {} if value.nil?
      raise Error, "#{source}: patient must be a mapping" unless value.is_a?(Hash)

      unknown = value.keys - PATIENT_KEYS
      raise Error, "#{source}: patient has unknown key(s) #{unknown.join(', ')} (known: #{PATIENT_KEYS.join(', ')})" if unknown.any?

      result = {}
      if value["hospital_id_format"].present?
        begin
          result[:hospital_id_format] = Regexp.new(value["hospital_id_format"].to_s)
        rescue RegexpError => e
          raise Error, "#{source}: patient.hospital_id_format is not a valid regular expression: #{e.message}"
        end
      end
      result[:hospital_id_format_hint] = value["hospital_id_format_hint"].to_s if value["hospital_id_format_hint"].present?
      result.freeze
    end

    def normalize_masters(value)
      @master_flags = {}
      return {}.freeze if value.nil?
      raise Error, "#{source}: masters must be a mapping of master => [name, ...]" unless value.is_a?(Hash)

      unknown = value.keys - MASTER_KEYS
      raise Error, "#{source}: masters has unknown key(s) #{unknown.join(', ')} (known: #{MASTER_KEYS.join(', ')})" if unknown.any?

      value.to_h do |key, entries|
        entries = [] if entries.nil?
        raise Error, "#{source}: masters.#{key} must be a list of non-blank strings" unless entries.is_a?(Array)

        names = []
        entries.each do |entry|
          name, flags = normalize_master_entry(key, entry)
          names << name
          next if flags.empty?

          merged = (@master_flags[key] ||= {})[name] ||= {}
          flags.each { |flag, flag_value| merged[flag] ||= flag_value }
        end
        [ key, names.uniq.freeze ]
      end.tap { @master_flags.each_value(&:freeze) }.freeze
    end

    # An entry is a non-blank name, or (only for masters listed in
    # MASTER_ENTRY_OPTIONS) a mapping with a name and boolean options.
    def normalize_master_entry(key, entry)
      return [ entry.strip, {} ] if entry.is_a?(String) && entry.strip.present?

      allowed = MASTER_ENTRY_OPTIONS[key]
      unless entry.is_a?(Hash) && allowed
        message = allowed ? "must be a list of non-blank strings or {name: ...} mappings" : "must be a list of non-blank strings"
        raise Error, "#{source}: masters.#{key} #{message}"
      end

      name = entry["name"]
      unless name.is_a?(String) && name.strip.present?
        raise Error, "#{source}: masters.#{key} entries given as a mapping need a non-blank name"
      end

      unknown = entry.keys - [ "name" ] - allowed
      if unknown.any?
        raise Error, "#{source}: masters.#{key} entry #{name} has unknown option(s) #{unknown.join(', ')} (known: #{allowed.join(', ')})"
      end

      flags = entry.except("name")
      validate_master_flags!(key, name, flags)

      [ name.strip, flags ]
    end

    # Options are booleans, except a team's color, which must be a palette key.
    def validate_master_flags!(key, name, flags)
      flags.each do |option, flag|
        if key == "teams" && option == "color"
          next if Team::COLOR_KEYS.include?(flag)

          raise Error, "#{source}: masters.teams entry #{name}: color must be one of #{Team::COLOR_KEYS.join(', ')}"
        end
        raise Error, "#{source}: masters.#{key} entry #{name}: options must be true or false" unless flag == true || flag == false
      end
    end
end
