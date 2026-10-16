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

  # top-level key => validator method (receives the raw value, returns the
  # normalized one, raises Error).
  SCHEMA = {
    "required_fields" => :normalize_required_fields,
    "patient" => :normalize_patient,
    "features" => :normalize_features,
    "masters" => :normalize_masters
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

  private

    def reject_team_fields_without_teams_feature!
      return if teams_enabled?

      required = @values.fetch("required_fields")
      lists = required.except(BY_PURPOSE_KEY).values + required.fetch(BY_PURPOSE_KEY, {}).values
      return unless lists.any? { |fields| fields.include?(TEAM_FIELD.to_sym) }

      raise Error, "#{source}: required_fields lists #{TEAM_FIELD}, which needs features.teams to be true"
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
    # typo fails the deploy instead of silently never being required. When the
    # database is not reachable yet (assets:precompile, db:create) the check is
    # skipped rather than failing the boot for an unrelated reason.
    def validate_field_names!(label, model, fields)
      attribute_names = REQUIRED_FIELD_MODELS.fetch(model).constantize.attribute_names
      unknown = fields - attribute_names
      return if unknown.empty?

      raise Error, "#{source}: #{label} has unknown field(s) #{unknown.join(', ')}"
    rescue ActiveRecord::ActiveRecordError
      nil
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
