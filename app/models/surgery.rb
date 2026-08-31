class Surgery < ApplicationRecord
  belongs_to :patient
  belongs_to :hospitalization, optional: true
  has_many :surgery_diagnosis_links, dependent: :destroy
  has_many :patient_diagnoses, through: :surgery_diagnosis_links
  has_many :surgery_procedure_selections, -> { order(:id) }, dependent: :destroy, inverse_of: :surgery
  has_many :selected_surgery_procedures, through: :surgery_procedure_selections, source: :surgery_procedure

  accepts_nested_attributes_for :surgery_procedure_selections,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["surgery_procedure_id"].blank? }

  validates :surgery_date, presence: true
  validates :anesthesia_method, presence: true
  validates :duration_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :patient_diagnoses_must_belong_to_patient
  validate :must_have_at_least_one_procedure_selection
  validate :no_more_than_five_procedure_selections
  validate :no_duplicate_procedure_selections
  validate :hospitalization_must_belong_to_same_patient
  validate :surgery_date_must_fall_within_hospitalization_period

  scope :linked_to_hospitalization, -> { where.not(hospitalization_id: nil) }
  scope :standalone, -> { where(hospitalization_id: nil) }
  scope :anesthesia_methods, -> { distinct.order(:anesthesia_method).pluck(:anesthesia_method).compact_blank }

  def self.filtered(keyword: nil, surgery_procedure_id: nil, anesthesia_method: nil, performed_from: nil, performed_to: nil)
    scope = all

    if keyword.present?
      pattern = "%#{sanitize_sql_like(keyword)}%"
      scope = scope.joins(:patient).where(
        "patients.name LIKE :pattern OR patients.hospital_id LIKE :pattern", pattern: pattern
      )
    end

    if surgery_procedure_id.present?
      scope = scope.joins(:surgery_procedure_selections)
                   .where(surgery_procedure_selections: { surgery_procedure_id: surgery_procedure_id })
                   .distinct
    end

    scope = scope.where(anesthesia_method: anesthesia_method) if anesthesia_method.present?
    scope = scope.where(surgery_date: performed_from..) if performed_from.present?
    scope = scope.where(surgery_date: ..performed_to) if performed_to.present?
    scope
  end

  def display_procedure_name
    procedure_display_names.presence || "-"
  end

  def procedure_names_display
    procedure_names.join("、").presence || "-"
  end

  def laterality_names_display
    active_surgery_procedure_selections.map(&:laterality_label).join("、").presence || "-"
  end

  def diagnosis_names_display
    patient_diagnoses.includes(:diagnosis).map(&:display_name).join("、").presence || "-"
  end

  def procedure_display_names
    active_surgery_procedure_selections.map(&:display_name).join("、").presence
  end

  def procedure_names
    active_surgery_procedure_selections.filter_map(&:procedure_name)
  end

  def active_surgery_procedure_selections
    surgery_procedure_selections.reject(&:marked_for_destruction?)
  end

  private

  def patient_diagnoses_must_belong_to_patient
    return if patient_diagnoses.empty? || patient_id.blank?
    return if patient_diagnoses.all? { |pd| pd.patient_id == patient_id }

    errors.add(:patient_diagnoses, "must all belong to the selected patient")
  end

  def must_have_at_least_one_procedure_selection
    return if procedure_names.any?

    errors.add(:surgery_procedure_selections, "must include at least one procedure")
  end

  def no_more_than_five_procedure_selections
    return if procedure_names.size <= 5

    errors.add(:surgery_procedure_selections, "must be five or fewer")
  end

  def no_duplicate_procedure_selections
    return if procedure_names.uniq.size == procedure_names.size

    errors.add(:surgery_procedure_selections, "must not include duplicate procedures")
  end

  def hospitalization_must_belong_to_same_patient
    return if hospitalization.blank? || patient_id.blank?
    return if hospitalization.patient_id == patient_id

    errors.add(:hospitalization, "must belong to the same patient as the surgery")
  end

  def surgery_date_must_fall_within_hospitalization_period
    return if hospitalization.blank? || surgery_date.blank?
    return if hospitalization.admission_date.blank?
    return if surgery_date >= hospitalization.admission_date &&
              (hospitalization.discharge_date.blank? || surgery_date <= hospitalization.discharge_date)

    errors.add(:surgery_date, "must fall within the linked hospitalization period")
  end
end
