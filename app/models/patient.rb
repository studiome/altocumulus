class Patient < ApplicationRecord
  include Auditable

  # Only the valid DB keys live here -- labels come from
  # config/locales/*.yml (models.patient.sex_options).
  SEX_KEYS = %w[male female other].freeze

  has_many :surgeries, dependent: :destroy
  has_many :patient_diagnoses, -> { recent_first }, dependent: :destroy
  has_many :hospitalizations, dependent: :destroy
  has_many :case_database_entries, dependent: :destroy

  validates :hospital_id, presence: true, uniqueness: true
  validate :hospital_id_matches_site_format
  validates :name, presence: true
  validates :date_of_birth, presence: true
  validates :sex, inclusion: { in: SEX_KEYS }, allow_blank: true

  scope :ordered, -> { order(:hospital_id) }

  def self.sex_options
    SEX_KEYS.index_with { |key| I18n.t("models.patient.sex_options.#{key}") }
  end

  def self.sex_form_options
    sex_options.map { |k, v| [ v, k ] }
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

  private

    # Optional per-site ID format (SiteConfig). Only checked when the ID is
    # being set or changed, so a legacy ID that predates the format does not
    # block unrelated edits of the patient.
    def hospital_id_matches_site_format
      format = SiteConfig.current.hospital_id_format
      return if format.nil? || hospital_id.blank? || !will_save_change_to_hospital_id?
      return if format.match?(hospital_id)

      hint = SiteConfig.current.hospital_id_format_hint
      if hint
        errors.add(:hospital_id, :invalid_site_format, hint: hint)
      else
        errors.add(:hospital_id, :invalid)
      end
    end
end
