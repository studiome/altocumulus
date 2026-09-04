module Auditable
  extend ActiveSupport::Concern

  IGNORED_CHANGE_ATTRIBUTES = %w[created_at updated_at].freeze

  included do
    after_create :record_create_audit_event
    after_update :record_update_audit_event
    after_destroy :record_destroy_audit_event
  end

  private

    def record_create_audit_event
      create_audit_event!("create", filtered_audit_changes(saved_changes))
    end

    def record_update_audit_event
      changes = filtered_audit_changes(saved_changes)
      return if changes.empty?

      create_audit_event!("update", changes)
    end

    def record_destroy_audit_event
      changes = attributes.except(*IGNORED_CHANGE_ATTRIBUTES).transform_values { |value| [ value, nil ] }
      create_audit_event!("destroy", changes)
    end

    def filtered_audit_changes(change_set)
      change_set.except(*IGNORED_CHANGE_ATTRIBUTES)
    end

    def create_audit_event!(action, change_data)
      AuditEvent.create!(
        auditable_type: self.class.name,
        auditable_id: id,
        action: action,
        record_label: to_s,
        change_data: change_data
      )
    end
end
