class Surgery < ApplicationRecord
  include Auditable

  SCHEDULING_TYPE_OPTIONS = { "elective" => "Elective", "emergency" => "Emergency" }.freeze

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
  validates :scheduling_type, presence: true, inclusion: { in: SCHEDULING_TYPE_OPTIONS.keys }
  validate :patient_diagnoses_must_belong_to_patient
  validate :must_have_at_least_one_procedure_selection
  validate :no_more_than_five_procedure_selections
  validate :no_duplicate_procedure_selections
  validate :hospitalization_must_belong_to_same_patient
  validate :surgery_date_must_fall_within_hospitalization_period
  validates :slot_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Emergency surgeries are intentionally unaffected by the slot rules: no rule
  # lookup, no capacity check, no time-of-day check. They must stay saveable on
  # any date, at any time, so a stray slot number is cleared rather than
  # rejected. Never turn this into a validation.
  before_validation :clear_slot_number_for_emergency

  scope :linked_to_hospitalization, -> { where.not(hospitalization_id: nil) }
  scope :standalone, -> { where(hospitalization_id: nil) }
  scope :anesthesia_methods, -> { distinct.order(:anesthesia_method).pluck(:anesthesia_method).compact_blank }
  scope :elective, -> { where(scheduling_type: "elective") }
  scope :emergency, -> { where(scheduling_type: "emergency") }

  def self.scheduling_type_form_options
    SCHEDULING_TYPE_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.filtered(keyword: nil, surgery_procedure_id: nil, anesthesia_method: nil, performed_from: nil, performed_to: nil, scheduling_type: nil)
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
    scope = scope.where(scheduling_type: scheduling_type) if scheduling_type.present?
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
    patient_diagnoses.map(&:display_name).join("、").presence || "-"
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

  def elective?
    scheduling_type == "elective"
  end

  def emergency?
    scheduling_type == "emergency"
  end

  def scheduling_type_label
    SCHEDULING_TYPE_OPTIONS[scheduling_type] || scheduling_type
  end

  def start_time_display
    start_time&.strftime("%H:%M") || "-"
  end

  def to_s
    "#{surgery_date || 'Date not set'} - #{patient}"
  end

  def duration_minutes
    return nil if duration_hours.blank?

    (duration_hours * 60).round
  end

  private

  def clear_slot_number_for_emergency
    self.slot_number = nil if emergency?
  end

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
