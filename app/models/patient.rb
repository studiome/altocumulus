class Patient < ApplicationRecord
  include Auditable

  has_many :surgeries, dependent: :destroy
  has_many :patient_diagnoses, -> { recent_first }, dependent: :destroy
  has_many :hospitalizations, dependent: :destroy

  validates :hospital_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :date_of_birth, presence: true

  scope :ordered, -> { order(:hospital_id) }

  def self.filtered(keyword: nil)
    scope = all
    if keyword.present?
      pattern = "%#{sanitize_sql_like(keyword)}%"
      scope = scope.where("name LIKE :pattern OR hospital_id LIKE :pattern", pattern: pattern)
    end
    scope
  end

  def to_s
    "#{hospital_id} - #{name}"
  end
end
