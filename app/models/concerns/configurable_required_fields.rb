# Presence validations for the fields a site (see SiteConfig) chose to make
# mandatory, on top of whatever the model always requires. The list is read
# from SiteConfig.current at validation time, not frozen at class load, so a
# swapped config (tests) takes effect immediately. Forms ask
# `required_attribute?` for the asterisk so the mark and the validation come
# from the same place.
#
# Some fields are only required in a situation (a hospitalization's purpose,
# see Hospitalization#conditional_required_attributes), so
# `required_attribute?` also takes the record, or the situation itself
# (`purpose:`), to answer for. Without either it answers only for the
# unconditional list.
module ConfigurableRequiredFields
  extend ActiveSupport::Concern

  included do
    validate :validate_configured_required_fields
  end

  class_methods do
    # The unconditional list (required whatever the record looks like).
    def configured_required_attributes
      SiteConfig.current.required_fields(model_name.element)
    end

    # situation: a record, or keyword options understood by
    # `conditional_required_attributes_for` (e.g. purpose: "examination").
    def required_attribute?(attribute, situation = nil, **options)
      attribute = attribute.to_sym
      return true if configured_required_attributes.include?(attribute)
      return false if situation.nil? && options.empty?

      situation = situation.is_a?(self) ? situation.conditional_required_options : options
      conditional_required_attributes_for(**situation).include?(attribute)
    end

    # Models with situational requirements override this.
    def conditional_required_attributes_for(**)
      []
    end
  end

  # What this record contributes to `conditional_required_attributes_for`.
  def conditional_required_options
    {}
  end

  def configured_required_attributes
    (self.class.configured_required_attributes +
      self.class.conditional_required_attributes_for(**conditional_required_options)).uniq
  end

  private

    def validate_configured_required_fields
      configured_required_attributes.each do |attribute|
        next if errors.added?(attribute, :blank)

        errors.add(attribute, :blank) if public_send(attribute).blank?
      end
    end
end
