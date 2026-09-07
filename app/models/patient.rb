class Patient < ApplicationRecord
  include Auditable

  SEX_OPTIONS = {
    "male" => "Male",
    "female" => "Female",
    "other" => "Other"
  }.freeze

  has_many :surgeries, dependent: :destroy
  has_many :patient_diagnoses, -> { recent_first }, dependent: :destroy
  has_many :hospitalizations, dependent: :destroy

  validates :hospital_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :date_of_birth, presence: true
  validates :sex, inclusion: { in: SEX_OPTIONS.keys }, allow_blank: true

  scope :ordered, -> { order(:hospital_id) }

  def self.sex_form_options
    SEX_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.filtered(keyword: nil)
    scope = all
    if keyword.present?
      pattern = "%#{sanitize_sql_like(keyword)}%"
      scope = scope.where("name LIKE :pattern OR hospital_id LIKE :pattern", pattern: pattern)
    end
    scope
  end

  def age
    return nil if date_of_birth.blank?

    today = Date.current
    years = today.year - date_of_birth.year
    years -= 1 if today.month < date_of_birth.month ||
                  (today.month == date_of_birth.month && today.day < date_of_birth.day)
    years
  end

  def to_s
    "#{hospital_id} - #{name}"
  end
end
