class Diagnosis < ApplicationRecord
  has_many :patient_diagnoses, dependent: :restrict_with_error
  has_many :hospitalization_diagnoses, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }
end
