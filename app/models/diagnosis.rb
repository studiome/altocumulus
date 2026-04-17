class Diagnosis < ApplicationRecord
  has_many :patient_diagnoses, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
