# A free-text memo for admins only (shift handoffs, equipment notes, etc.).
# Unlike Holiday's per-date note, this is not tied to a calendar date.
# user is optional so a note survives its author's account being removed.
class AdminNote < ApplicationRecord
  belongs_to :user, optional: true

  validates :body, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
