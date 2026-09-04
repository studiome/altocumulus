module AuditsAssociatedChanges
  extend ActiveSupport::Concern

  IGNORED_ASSOCIATED_AUDIT_ATTRIBUTES = %w[id created_at updated_at].freeze

  included do
    class_attribute :audit_parent_association, instance_accessor: false
    class_attribute :audit_parent_foreign_key, instance_accessor: false

    after_create :record_associated_create_audit_event
    after_update :record_associated_update_audit_event
    after_destroy :record_associated_destroy_audit_event
  end

  class_methods do
    def audits_associated_changes_to(association, foreign_key:)
      self.audit_parent_association = association
      self.audit_parent_foreign_key = foreign_key.to_s
    end
  end

  private

    def record_associated_create_audit_event
      record_associated_audit_event!(filtered_associated_audit_changes(saved_changes))
    end

    def record_associated_update_audit_event
      changes = filtered_associated_audit_changes(saved_changes)
      return if changes.empty?

      record_associated_audit_event!(changes)
    end

    def record_associated_destroy_audit_event
      return if destroyed_by_association.present?

      changes = filtered_associated_audit_changes(attributes).transform_values { |value| [ value, nil ] }
      return if changes.empty?

      record_associated_audit_event!(changes)
    end

    def filtered_associated_audit_changes(change_set)
      change_set.except(*IGNORED_ASSOCIATED_AUDIT_ATTRIBUTES, self.class.audit_parent_foreign_key)
                .transform_keys { |attribute| "#{self.class.model_name.singular}[#{id}].#{attribute}" }
    end

    def record_associated_audit_event!(changes)
      parent = public_send(self.class.audit_parent_association)

      AuditEvent.create!(
        auditable_type: parent.class.name,
        auditable_id: parent.id,
        action: "update",
        record_label: parent.to_s,
        change_data: changes
      )
    end
end
