class SurgeryProcedure < ApplicationRecord
  has_many :surgery_procedure_selections, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }

  def self.filtered(keyword: nil)
    return all if keyword.blank?

    where(like_condition("name"), pattern: like_pattern(keyword))
  end

  def to_s
    name
  end
end
