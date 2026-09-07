class AuditEvent < ApplicationRecord
  ACTIONS = %w[create update destroy].freeze
  AUDITABLE_TYPES = %w[Patient Surgery Hospitalization].freeze

  belongs_to :user, optional: true

  validates :auditable_type, presence: true, inclusion: { in: AUDITABLE_TYPES }
  validates :auditable_id, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :record_label, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.filtered(auditable_type: nil, action: nil, user_id: nil)
    scope = all
    scope = scope.where(auditable_type: auditable_type) if AUDITABLE_TYPES.include?(auditable_type)
    scope = scope.where(action: action) if ACTIONS.include?(action)
    scope = scope.where(user_id: user_id) if user_id.present?
    scope
  end

  # Unlike every other *_options method in this app (which look labels up
  # from config/locales/*.yml under models.<model>.*_options), AUDITABLE_TYPES
  # is deliberately keyed off each actual model class's own
  # `model_name.human` instead of a new set of translation keys: its values
  # (Patient/Surgery/Hospitalization) already ARE real model class names, and
  # #audit_change_label in AuditEventsHelper already resolves an associated
  # model's display name the same way for the change-history table's row
  # labels. Reusing it here avoids a second, redundant Japanese translation
  # of "Patient"/"Surgery"/"Hospitalization" alongside
  # activerecord.models.patient/surgery/hospitalization, and stays in sync
  # automatically if those ever change.
  def self.auditable_type_options
    AUDITABLE_TYPES.index_with { |type| type.constantize.model_name.human }
  end

  def self.action_options
    ACTIONS.index_with { |key| I18n.t("models.audit_event.action_options.#{key}") }
  end

  def self.auditable_type_form_options
    auditable_type_options.map { |k, v| [ v, k ] }
  end

  def self.action_form_options
    action_options.map { |k, v| [ v, k ] }
  end

  def auditable_type_label
    self.class.auditable_type_options[auditable_type] || auditable_type
  end

  def action_label
    self.class.action_options[action] || action
  end
end
