class PatientDiagnosis < ApplicationRecord
  belongs_to :patient
  belongs_to :diagnosis

  delegate :name, to: :diagnosis, prefix: true

  validates :diagnosed_on, presence: true

  scope :recent_first, -> { order(diagnosed_on: :desc, created_at: :desc) }
end
