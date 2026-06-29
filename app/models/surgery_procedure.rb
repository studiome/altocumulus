class SurgeryProcedure < ApplicationRecord
  has_many :surgery_procedure_selections, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }
end
