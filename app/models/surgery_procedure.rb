class SurgeryProcedure < ApplicationRecord
  has_many :surgery_procedure_selections, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }

  def self.filtered(keyword: nil)
    return all if keyword.blank?

    where("name LIKE ?", "%#{sanitize_sql_like(keyword)}%")
  end

  def to_s
    name
  end
end
