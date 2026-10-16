# Presence validations for the fields a site (see SiteConfig) chose to make
# mandatory, on top of whatever the model always requires. The list is read
# from SiteConfig.current at validation time, not frozen at class load, so a
# swapped config (tests) takes effect immediately. Forms ask
# `required_attribute?` for the asterisk so the mark and the validation come
# from the same place.
module ConfigurableRequiredFields
  extend ActiveSupport::Concern

  included do
    validate :validate_configured_required_fields
  end

  class_methods do
    def configured_required_attributes
      SiteConfig.current.required_fields(model_name.element)
    end

    def required_attribute?(attribute)
      configured_required_attributes.include?(attribute.to_sym)
    end
  end

  private

    def validate_configured_required_fields
      self.class.configured_required_attributes.each do |attribute|
        next if errors.added?(attribute, :blank)

        errors.add(attribute, :blank) if public_send(attribute).blank?
      end
    end
end
