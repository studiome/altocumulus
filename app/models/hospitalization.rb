class Hospitalization < ApplicationRecord
  OUTCOME_OPTIONS = {
    "recovered" => "Recovered",
    "improved" => "Improved",
    "unchanged" => "Unchanged",
    "worsened" => "Worsened",
    "transferred" => "Transferred",
    "died" => "Died"
  }.freeze

  DISCHARGE_DESTINATION_OPTIONS = {
    "home" => "Home",
    "hospital" => "Another Hospital",
    "facility" => "Nursing Facility",
    "death" => "Death",
    "other" => "Other"
  }.freeze

  belongs_to :patient
  has_many :hospitalization_diagnoses, -> { order(:id) }, dependent: :destroy, inverse_of: :hospitalization
  has_many :diagnoses, through: :hospitalization_diagnoses

  accepts_nested_attributes_for :hospitalization_diagnoses,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["diagnosis_id"].blank? }

  validates :admission_date, presence: true
  validates :reason, presence: true
  validates :planned_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :outcome, inclusion: { in: OUTCOME_OPTIONS.keys }, allow_blank: true
  validates :discharge_destination, inclusion: { in: DISCHARGE_DESTINATION_OPTIONS.keys }, allow_blank: true
  validate :must_have_at_least_one_diagnosis
  validate :no_duplicate_diagnoses
  validate :discharge_date_on_or_after_admission_date
  validate :outcome_required_when_discharged
  validate :discharge_fields_require_discharge_date
  validate :no_overlapping_hospitalization_period

  scope :discharged, -> { where.not(discharge_date: nil) }
  scope :in_hospital, -> { where(discharge_date: nil) }
  scope :admitted_between, ->(from, to) {
    scope = all
    scope = scope.where(admission_date: from..) if from.present?
    scope = scope.where(admission_date: ..to) if to.present?
    scope
  }

  def self.outcome_form_options
    OUTCOME_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.discharge_destination_form_options
    DISCHARGE_DESTINATION_OPTIONS.map { |k, v| [ v, k ] }
  end

  def diagnosis_names_display
    active_hospitalization_diagnoses.filter_map(&:diagnosis_name).join("、").presence || "-"
  end

  def active_hospitalization_diagnoses
    hospitalization_diagnoses.reject(&:marked_for_destruction?)
  end

  def discharged?
    discharge_date.present?
  end

  def in_hospital?
    admission_date.present? && discharge_date.blank?
  end

  def length_of_stay
    return nil unless discharged?

    (discharge_date - admission_date).to_i + 1
  end

  def days_since_admission
    return nil unless in_hospital?

    (Date.current - admission_date).to_i + 1
  end

  def status_label
    discharged? ? "Discharged" : "In Hospital"
  end

  def outcome_label
    OUTCOME_OPTIONS[outcome] || "-"
  end

  def discharge_destination_label
    DISCHARGE_DESTINATION_OPTIONS[discharge_destination] || "-"
  end

  def to_s
    "#{patient} (#{admission_date} - #{discharge_date || 'in hospital'})"
  end

  private

    def diagnosis_ids_in_use
      active_hospitalization_diagnoses.filter_map(&:diagnosis_id)
    end

    def must_have_at_least_one_diagnosis
      return if diagnosis_ids_in_use.any?

      errors.add(:hospitalization_diagnoses, "must include at least one diagnosis")
    end

    def no_duplicate_diagnoses
      ids = diagnosis_ids_in_use
      return if ids.uniq.size == ids.size

      errors.add(:hospitalization_diagnoses, "must not include duplicate diagnoses")
    end

    def discharge_date_on_or_after_admission_date
      return if discharge_date.blank? || admission_date.blank?
      return if discharge_date >= admission_date

      errors.add(:discharge_date, "must be on or after the admission date")
    end

    def outcome_required_when_discharged
      return if discharge_date.blank?
      return if outcome.present?

      errors.add(:outcome, "can't be blank")
    end

    def discharge_fields_require_discharge_date
      return if discharge_date.present?

      errors.add(:outcome, "can only be set together with a discharge date") if outcome.present?
      if discharge_destination.present?
        errors.add(:discharge_destination, "can only be set together with a discharge date")
      end
    end

    def no_overlapping_hospitalization_period
      return if patient_id.blank? || admission_date.blank?

      scope = Hospitalization.where(patient_id: patient_id)
      scope = scope.where.not(id: id) if persisted?
      conflict = scope.where(
        "(:end_date IS NULL OR admission_date <= :end_date) AND (discharge_date IS NULL OR discharge_date >= :start_date)",
        start_date: admission_date, end_date: discharge_date
      ).exists?

      errors.add(:admission_date, "overlaps another hospitalization for this patient") if conflict
    end
end
