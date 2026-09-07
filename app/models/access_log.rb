class AccessLog < ApplicationRecord
  EVENTS = %w[login logout timeout login_failed].freeze

  belongs_to :user, optional: true

  validates :event, presence: true, inclusion: { in: EVENTS }

  scope :recent_first, -> { order(created_at: :desc) }
end
