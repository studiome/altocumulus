module AuditEventsHelper
  # Associated-record changes are recorded with a composite key of the form
  # "model_name[id].attribute" (see AuditsAssociatedChanges) instead of a
  # plain attribute name on the auditable record itself.
  ASSOCIATED_KEY_PATTERN = /\A(?<model>[a-z_]+)\[(?<id>\d+)\]\.(?<attribute>.+)\z/

  # Renders each change_data row as { label:, before:, after: } using the
  # attribute's own human name and, where possible, the referenced record's
  # label instead of a raw foreign key id — never the raw JSON hash.
  def audit_change_rows(audit_event)
    audit_event.change_data.map do |key, values|
      before_value, after_value = values
      model_class, attribute = audit_change_model_and_attribute(audit_event, key)

      {
        label: audit_change_label(model_class, attribute, key),
        before: audit_change_value(model_class, attribute, before_value),
        after: audit_change_value(model_class, attribute, after_value)
      }
    end
  end

  private

    def audit_change_model_and_attribute(audit_event, key)
      if (match = ASSOCIATED_KEY_PATTERN.match(key))
        [ match[:model].classify.safe_constantize, match[:attribute] ]
      else
        [ audit_event.auditable_type.safe_constantize, key ]
      end
    end

    def audit_change_label(model_class, attribute, key)
      match = ASSOCIATED_KEY_PATTERN.match(key)
      attribute_label = model_class ? model_class.human_attribute_name(attribute) : attribute.humanize

      return attribute_label unless match

      model_label = model_class ? model_class.model_name.human : match[:model].humanize
      "#{model_label} ##{match[:id]} - #{attribute_label}"
    end

    def audit_change_value(model_class, attribute, value)
      return "-" if value.nil? || value == ""
      return audit_boolean_label(value) if value == true || value == false

      column_type = model_class&.columns_hash&.[](attribute.to_s)&.type

      case column_type
      when :date
        audit_format_date(value)
      when :datetime
        audit_format_datetime(value)
      when :time
        audit_format_time(value)
      when :boolean
        audit_boolean_label(value)
      else
        attribute.to_s.end_with?("_id") ? audit_resolve_foreign_key(attribute, value) : value.to_s
      end
    end

    def audit_boolean_label(value)
      value ? I18n.t("helpers.audit_events.yes") : I18n.t("helpers.audit_events.no")
    end

    def audit_format_date(value)
      Date.parse(value.to_s).strftime("%Y-%m-%d")
    rescue ArgumentError, TypeError
      value.to_s
    end

    def audit_format_datetime(value)
      Time.zone.parse(value.to_s).strftime("%Y-%m-%d %H:%M:%S")
    rescue ArgumentError, TypeError
      value.to_s
    end

    def audit_format_time(value)
      Time.zone.parse(value.to_s).strftime("%H:%M")
    rescue ArgumentError, TypeError
      value.to_s
    end

    # Best-effort label resolution for foreign keys (e.g. "diagnosis_id" ->
    # Diagnosis#find). Only ever looked up once per changed value (a single
    # audit event has a handful of changed attributes), so this does not
    # introduce N+1 queries across a list of audit events. Falls back to the
    # raw id whenever the attribute name doesn't map to a real association.
    def audit_resolve_foreign_key(attribute, value)
      klass = attribute.to_s.delete_suffix("_id").classify.safe_constantize
      return value.to_s unless klass && klass < ActiveRecord::Base

      record = klass.find_by(id: value)
      record ? record.to_s : "##{value} (not found)"
    end
end
