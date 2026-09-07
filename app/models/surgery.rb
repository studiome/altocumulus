class Surgery < ApplicationRecord
  include Auditable

  # Only the valid DB keys live here -- labels come from
  # config/locales/*.yml (models.surgery.*_options), see Hospitalization for
  # the same pattern.
  SCHEDULING_TYPE_KEYS = %w[elective emergency].freeze
  SURGERY_DATE_STATUS_KEYS = %w[scheduled undecided].freeze

  belongs_to :patient
  belongs_to :hospitalization, optional: true
  has_many :surgery_diagnosis_links, dependent: :destroy
  has_many :patient_diagnoses, through: :surgery_diagnosis_links
  has_many :surgery_procedure_selections, -> { order(:id) }, dependent: :destroy, inverse_of: :surgery
  has_many :selected_surgery_procedures, through: :surgery_procedure_selections, source: :surgery_procedure

  accepts_nested_attributes_for :surgery_procedure_selections,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["surgery_procedure_id"].blank? }

  validates :anesthesia_method, presence: true
  validates :duration_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :scheduling_type, presence: true, inclusion: { in: SCHEDULING_TYPE_KEYS }
  validate :patient_diagnoses_must_belong_to_patient
  validate :must_have_at_least_one_procedure_selection
  validate :no_more_than_five_procedure_selections
  validate :no_duplicate_procedure_selections
  validate :hospitalization_must_belong_to_same_patient
  validate :surgery_date_must_fall_within_hospitalization_period
  validate :valid_surgery_date_status
  validates :slot_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :operation_order, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

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
  scope :undated, -> { where(surgery_date: nil) }
  scope :dated, -> { where.not(surgery_date: nil) }
  # SQL's default null ordering puts NULLs first on an ASC sort, which would
  # otherwise scatter undated surgeries to the front of a "most recent first"
  # list. `surgery_date IS NULL` is 0/false for a dated row and 1/true for an
  # undated one, so ordering by it ascending first always pushes undated rows
  # to the very end regardless of the direction of the date sort that follows.
  scope :ordered_by_surgery_date, -> { order(Arel.sql("surgery_date IS NULL"), surgery_date: :desc, created_at: :desc) }

  def self.scheduling_type_options
    SCHEDULING_TYPE_KEYS.index_with { |key| I18n.t("models.surgery.scheduling_type_options.#{key}") }
  end

  def self.surgery_date_status_options
    SURGERY_DATE_STATUS_KEYS.index_with { |key| I18n.t("models.surgery.surgery_date_status_options.#{key}") }
  end

  def self.scheduling_type_form_options
    scheduling_type_options.map { |k, v| [ v, k ] }
  end

  def self.surgery_date_status_form_options
    surgery_date_status_options.map { |k, v| [ v, k ] }
  end

  def self.filtered(keyword: nil, surgery_procedure_id: nil, anesthesia_method: nil, performed_from: nil, performed_to: nil, scheduling_type: nil, undated: nil)
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
    # A NULL surgery_date never satisfies either range comparison, so a
    # date-range search already excludes undated surgeries with no extra code.
    scope = scope.where(surgery_date: performed_from..) if performed_from.present?
    scope = scope.where(surgery_date: ..performed_to) if performed_to.present?
    scope = scope.where(scheduling_type: scheduling_type) if scheduling_type.present?
    scope = scope.undated if ActiveModel::Type::Boolean.new.cast(undated)
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
    self.class.scheduling_type_options[scheduling_type] || scheduling_type
  end

  def start_time_display
    start_time&.strftime("%H:%M") || "-"
  end

  def surgery_date_display
    surgery_date ? I18n.l(surgery_date, format: :default) : I18n.t("models.surgery.surgery_date_display_undated")
  end

  # Lets a form explicitly choose between a scheduled surgery_date and
  # "undecided" (see Admission#operation_date_status in alphaledger, the same
  # technique). The default reads back whatever is actually persisted, so any
  # code path that never touches this attribute (dup, seeds, console, an
  # ordinary partial update) sees the value implied by the data rather than
  # being forced through this choice.
  attr_writer :surgery_date_status

  def surgery_date_status
    @surgery_date_status.presence || (persisted? && surgery_date.nil? ? "undecided" : "scheduled")
  end

  def surgery_date_status_specified?
    @surgery_date_status.present?
  end

  def to_s
    "#{surgery_date || I18n.t('models.surgery.to_s_date_not_set')} - #{patient}"
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

    errors.add(:patient_diagnoses, :must_all_belong_to_selected_patient)
  end

  def must_have_at_least_one_procedure_selection
    return if procedure_names.any?

    errors.add(:surgery_procedure_selections, :must_include_at_least_one_procedure)
  end

  def no_more_than_five_procedure_selections
    return if procedure_names.size <= 5

    errors.add(:surgery_procedure_selections, :too_many_procedure_selections)
  end

  def no_duplicate_procedure_selections
    return if procedure_names.uniq.size == procedure_names.size

    errors.add(:surgery_procedure_selections, :no_duplicate_procedure_selections)
  end

  def hospitalization_must_belong_to_same_patient
    return if hospitalization.blank? || patient_id.blank?
    return if hospitalization.patient_id == patient_id

    errors.add(:hospitalization, :must_belong_to_same_patient_as_surgery)
  end

  def surgery_date_must_fall_within_hospitalization_period
    return if hospitalization.blank? || surgery_date.blank?
    return if hospitalization.effective_admission_date.blank?
    return if surgery_date >= hospitalization.effective_admission_date &&
              (hospitalization.discharge_date.blank? || surgery_date <= hospitalization.discharge_date)

    errors.add(:surgery_date, :must_fall_within_hospitalization_period)
  end

  # Only checked when surgery_date_status is explicitly assigned (i.e. the
  # form submitted it), so dup/seeds/console/plain attribute updates that
  # never set it are unaffected. Never silently clears surgery_date itself --
  # a contradiction is surfaced as an error for the user to resolve.
  def valid_surgery_date_status
    return unless surgery_date_status_specified?

    unless SURGERY_DATE_STATUS_KEYS.include?(@surgery_date_status)
      errors.add(:surgery_date_status, :not_valid)
      return
    end

    raw = surgery_date_before_type_cast
    if @surgery_date_status == "undecided"
      errors.add(:surgery_date, :must_be_blank_when_undecided) if raw.present?
    elsif raw.blank?
      errors.add(:surgery_date, :must_be_entered_or_undecided)
    end
  end
end
