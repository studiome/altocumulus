class Patient < ApplicationRecord
  has_many :surgeries, dependent: :destroy
  has_many :patient_diagnoses, -> { recent_first }, dependent: :destroy

  validates :hospital_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :date_of_birth, presence: true
end
