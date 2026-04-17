class Surgery < ApplicationRecord
  attribute :laterality, :string, default: "none"

  belongs_to :patient
  has_many :surgery_diagnoses, dependent: :destroy
  has_many :patient_diagnoses, through: :surgery_diagnoses
  has_many :surgery_procedure_selections, -> { order(:id) }, dependent: :destroy, inverse_of: :surgery
  has_many :selected_surgery_procedures, through: :surgery_procedure_selections, source: :surgery_procedure
  belongs_to :surgery_procedure,
             class_name: "SurgeryProcedure",
             foreign_key: :procedure,
             primary_key: :name,
             optional: true

  accepts_nested_attributes_for :surgery_procedure_selections,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["surgery_procedure_id"].blank? }

  LATERALITY_PREFIXES = {
    "right" => "Right",
    "left" => "Left",
    "bilateral" => "Bilateral",
    "none" => ""
  }.freeze

  validates :surgery_date, presence: true
  validates :anesthesia_method, presence: true
  validates :duration_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :laterality, inclusion: { in: LATERALITY_PREFIXES.keys }
  validate :patient_diagnoses_must_belong_to_patient
  validate :procedure_must_exist
  validate :must_have_at_least_one_procedure_selection
  validate :no_more_than_five_procedure_selections
  validate :no_duplicate_procedure_selections

  before_validation :sync_primary_procedure

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
    patient_diagnoses.includes(:diagnosis).map(&:diagnosis_name).join("、").presence || "-"
  end

  def procedure_display_names
    active_surgery_procedure_selections.map(&:display_name).join("、").presence || procedure
  end

  def procedure_names
    active_surgery_procedure_selections.filter_map do |selection|
      selection.procedure_name
    end
  end

  def active_surgery_procedure_selections
    surgery_procedure_selections.reject(&:marked_for_destruction?)
  end

  private

  def sync_primary_procedure
    return if active_surgery_procedure_selections.empty?

    self.procedure = procedure_names.first
  end

  def patient_diagnoses_must_belong_to_patient
    return if patient_diagnoses.empty? || patient_id.blank?
    return if patient_diagnoses.all? { |patient_diagnosis| patient_diagnosis.patient_id == patient_id }

    errors.add(:patient_diagnoses, "must all belong to the selected patient")
  end

  def procedure_must_exist
    return if procedure.blank?
    return if SurgeryProcedure.exists?(name: procedure)

    errors.add(:procedure, "must be selected from the procedure list")
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
