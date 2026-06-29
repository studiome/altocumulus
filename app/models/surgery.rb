class Surgery < ApplicationRecord
  belongs_to :patient
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
end
