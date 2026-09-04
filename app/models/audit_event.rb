class AuditEvent < ApplicationRecord
  ACTIONS = %w[create update destroy].freeze
  AUDITABLE_TYPES = %w[Patient Surgery Hospitalization].freeze

  validates :auditable_type, presence: true, inclusion: { in: AUDITABLE_TYPES }
  validates :auditable_id, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :record_label, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.filtered(auditable_type: nil, action: nil)
    scope = all
    scope = scope.where(auditable_type: auditable_type) if AUDITABLE_TYPES.include?(auditable_type)
    scope = scope.where(action: action) if ACTIONS.include?(action)
    scope
  end
end
