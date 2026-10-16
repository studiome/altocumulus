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

  PATIENT_KEYS = %w[hospital_id_format hospital_id_format_hint].freeze

  # Keys of the masters section: the names a deployment wants present in the
  # admin-editable master tables (see SiteMasterSeeder, `site:seed_masters`).
  MASTER_KEYS = %w[departments surgery_locations surgical_devices].freeze

  # top-level key => validator method (receives the raw value, returns the
  # normalized one, raises Error).
  SCHEMA = {
    "required_fields" => :normalize_required_fields,
    "patient" => :normalize_patient,
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
    @values.freeze
  end

  # Attribute names (symbols) that must be present for the given model
  # ("hospitalization" / "surgery"), beyond what the model always requires.
  def required_fields(model)
    @values.fetch("required_fields").fetch(model.to_s, [])
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

  private

    def normalize_required_fields(value)
      return {} if value.nil?
      raise Error, "#{source}: required_fields must be a mapping of model => [field, ...]" unless value.is_a?(Hash)

      unknown_models = value.keys - REQUIRED_FIELD_MODELS.keys
      if unknown_models.any?
        raise Error, "#{source}: required_fields has unknown model(s) #{unknown_models.join(', ')} (known: #{REQUIRED_FIELD_MODELS.keys.join(', ')})"
      end

      value.to_h do |model, fields|
        fields = [] if fields.nil?
        unless fields.is_a?(Array) && fields.all?(String)
          raise Error, "#{source}: required_fields.#{model} must be a list of field names"
        end
        validate_field_names!(model, fields)
        [ model, fields.map(&:to_sym).uniq.freeze ]
      end.freeze
    end

    # Field names are checked against the model's real attribute names so a
    # typo fails the deploy instead of silently never being required. When the
    # database is not reachable yet (assets:precompile, db:create) the check is
    # skipped rather than failing the boot for an unrelated reason.
    def validate_field_names!(model, fields)
      attribute_names = REQUIRED_FIELD_MODELS.fetch(model).constantize.attribute_names
      unknown = fields - attribute_names
      return if unknown.empty?

      raise Error, "#{source}: required_fields.#{model} has unknown field(s) #{unknown.join(', ')}"
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
      return {}.freeze if value.nil?
      raise Error, "#{source}: masters must be a mapping of master => [name, ...]" unless value.is_a?(Hash)

      unknown = value.keys - MASTER_KEYS
      raise Error, "#{source}: masters has unknown key(s) #{unknown.join(', ')} (known: #{MASTER_KEYS.join(', ')})" if unknown.any?

      value.to_h do |key, names|
        names = [] if names.nil?
        unless names.is_a?(Array) && names.all? { |name| name.is_a?(String) && name.strip.present? }
          raise Error, "#{source}: masters.#{key} must be a list of non-blank strings"
        end
        [ key, names.map(&:strip).uniq.freeze ]
      end.freeze
    end
end
