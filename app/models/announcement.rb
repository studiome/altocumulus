# A short operational notice, managed only by admins, shown to every user on
# the operations calendar while published: true. Unpublishing (rather than
# deleting) lets an admin draft a notice ahead of time or retire an old one
# without losing its text.
class Announcement < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true

  scope :published, -> { where(published: true) }
  scope :recent_first, -> { order(created_at: :desc) }

  def to_s
    title
  end
end
