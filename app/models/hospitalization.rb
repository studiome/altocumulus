class Hospitalization < ApplicationRecord
  include Auditable

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

  RESERVATION_STATUS_OPTIONS = {
    "requested" => "Requested",
    "waiting" => "Waiting for Admission",
    "date_fixed" => "Admission Date Fixed",
    "surgery_date_fixed" => "Surgery Date Fixed",
    "admitted" => "Admitted",
    "admitted_other_dept" => "Admitted (Other Dept.)",
    "on_hold" => "On Hold",
    "discharged" => "Discharged"
  }.freeze

  PURPOSE_OPTIONS = {
    "surgery" => "Surgery",
    "examination" => "Examination / Procedure",
    "chemotherapy" => "Chemotherapy"
  }.freeze

  ADMIN_STATUS_OPTIONS = {
    "unconfirmed" => "Unconfirmed",
    "confirmed" => "Confirmed"
  }.freeze

  # The index page's single "Status" filter mixes two kinds of condition: the
  # derived in_hospital/discharged state, and reservation-workflow shortcuts
  # (upcoming/waiting/unconfirmed/recently_updated/referred). Keeping them as
  # one list (rather than a second dropdown) matches the existing filter bar
  # layout that filter_bar_layout_test pins down.
  STATUS_FILTER_OPTIONS = {
    "in_hospital" => "In Hospital",
    "discharged" => "Discharged",
    "upcoming" => "Upcoming",
    "waiting" => "Waiting",
    "unconfirmed" => "Unconfirmed",
    "recently_updated" => "Recently Updated",
    "referred" => "Referred"
  }.freeze

  WAITING_RESERVATION_STATUSES = %w[requested waiting on_hold].freeze
  RECENTLY_UPDATED_WITHIN = 2.days

  belongs_to :patient
  has_many :hospitalization_diagnoses, -> { order(:id) }, dependent: :destroy, inverse_of: :hospitalization
  has_many :diagnoses, through: :hospitalization_diagnoses
  has_many :surgeries

  before_destroy :unlink_surgeries

  accepts_nested_attributes_for :hospitalization_diagnoses,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["diagnosis_id"].blank? }

  validates :reason, presence: true
  validates :planned_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :outcome, inclusion: { in: OUTCOME_OPTIONS.keys }, allow_blank: true
  validates :discharge_destination, inclusion: { in: DISCHARGE_DESTINATION_OPTIONS.keys }, allow_blank: true
  validates :reservation_status, inclusion: { in: RESERVATION_STATUS_OPTIONS.keys }
  validates :purpose, inclusion: { in: PURPOSE_OPTIONS.keys }
  validates :admin_status, inclusion: { in: ADMIN_STATUS_OPTIONS.keys }
  validate :valid_date_values
  validate :admission_date_or_scheduled_admission_date_required
  validate :must_have_at_least_one_diagnosis
  validate :no_duplicate_diagnoses
  validate :discharge_date_on_or_after_admission_date
  validate :outcome_required_when_discharged
  validate :discharge_fields_require_discharge_date
  validate :no_overlapping_hospitalization_period
  validate :linked_surgeries_must_remain_within_period
  validate :linked_surgeries_must_belong_to_same_patient

  before_validation :reset_linked_surgeries_memo

  # A non-admin's update always drops back to "unconfirmed", regardless of
  # whether admin_status itself was touched (it is not even in the
  # controller's strong parameters, so this is the actual enforcement point).
  # Only an admin (via the #confirm action) can make it "confirmed". A save
  # with no Current.user (console, seeds, background jobs) is treated as a
  # trusted system actor and left alone.
  before_update :reset_admin_status_for_non_admin_update,
                unless: -> { Current.user.nil? || Current.user.admin? }

  # The snapshot records what the patient looked like at reservation time, so
  # it is only (re)captured when the patient link itself is established or
  # changes -- never on an ordinary field edit, or it would silently drift
  # away from being a point-in-time record.
  before_save :capture_patient_snapshot, if: -> { new_record? || patient_id_changed? }

  # No default_scope: it would fight the deleted list, restore, and admin
  # tooling, which all need to see discarded records. Every other read path
  # (index, LedgerStatistics, jbuilder, associations shown to end users) has
  # to opt in to .active explicitly.
  scope :active, -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }
  scope :discharged, -> { where.not(discharge_date: nil) }
  scope :in_hospital, -> { where(discharge_date: nil).where(admission_date: ..Date.current) }
  scope :upcoming, -> { where("COALESCE(admission_date, scheduled_admission_date) >= ?", Date.current) }
  scope :waiting, -> { where(reservation_status: WAITING_RESERVATION_STATUSES) }
  scope :unconfirmed, -> { where(admin_status: "unconfirmed") }
  scope :recently_updated, -> { where("updated_at >= ?", RECENTLY_UPDATED_WITHIN.ago) }
  scope :referred, -> { where.not(referred_from: [ nil, "" ]) }
  # Reservation-stage hospitalizations only carry scheduled_admission_date, so
  # the effective admission date (actual if present, otherwise scheduled) is
  # what a date-range filter or sort should compare against.
  scope :admitted_between, ->(from, to) {
    scope = all
    scope = scope.where("COALESCE(admission_date, scheduled_admission_date) >= ?", from) if from.present?
    scope = scope.where("COALESCE(admission_date, scheduled_admission_date) <= ?", to) if to.present?
    scope
  }

  def self.outcome_form_options
    OUTCOME_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.discharge_destination_form_options
    DISCHARGE_DESTINATION_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.reservation_status_form_options
    RESERVATION_STATUS_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.purpose_form_options
    PURPOSE_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.admin_status_form_options
    ADMIN_STATUS_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.status_filter_form_options
    STATUS_FILTER_OPTIONS.map { |k, v| [ v, k ] }
  end

  def self.filtered(keyword: nil, diagnosis_id: nil, status: nil, admitted_from: nil, admitted_to: nil)
    scope = active

    if keyword.present?
      pattern = "%#{sanitize_sql_like(keyword)}%"
      scope = scope.joins(:patient).where(
        "patients.name LIKE :pattern OR patients.hospital_id LIKE :pattern OR hospitalizations.reason LIKE :pattern",
        pattern: pattern
      )
    end

    if diagnosis_id.present?
      scope = scope.joins(:hospitalization_diagnoses)
                   .where(hospitalization_diagnoses: { diagnosis_id: diagnosis_id })
                   .distinct
    end

    case status
    when "in_hospital" then scope = scope.in_hospital
    when "discharged" then scope = scope.discharged
    when "upcoming" then scope = scope.upcoming
    when "waiting" then scope = scope.waiting
    when "unconfirmed" then scope = scope.unconfirmed
    when "recently_updated" then scope = scope.recently_updated
    when "referred" then scope = scope.referred
    end

    scope.admitted_between(admitted_from, admitted_to)
  end

  def diagnosis_names_display
    active_hospitalization_diagnoses.filter_map(&:diagnosis_name).join("、").presence || "-"
  end

  def active_hospitalization_diagnoses
    hospitalization_diagnoses.reject(&:marked_for_destruction?)
  end

  # The actual admission_date once the patient has checked in; falls back to
  # the scheduled_admission_date while the hospitalization is still a
  # reservation. Overlap/period validations and sorting/filtering are all
  # expressed in terms of this single effective date.
  def effective_admission_date
    admission_date || scheduled_admission_date
  end

  def deleted?
    deleted_at.present?
  end

  # Logical delete only: surgeries stay linked so a restore puts everything
  # back exactly as it was. Real destruction (see #unlink_surgeries) is a
  # separate, physical-only path that this never calls.
  def discard!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def discharged?
    discharge_date.present?
  end

  def in_hospital?
    admission_date.present? && admission_date <= Date.current && discharge_date.blank?
  end

  def length_of_stay
    return nil unless discharged? && admission_date.present?

    (discharge_date - admission_date).to_i + 1
  end

  def days_since_admission
    return nil unless in_hospital?

    (Date.current - admission_date).to_i + 1
  end

  # status_label is a derived read of the actual state (has the patient
  # checked in, are they discharged) and is intentionally independent from
  # reservation_status, which is a separate, user-selected field.
  def status_label
    return "Discharged" if discharged?
    return "In Hospital" if in_hospital?

    "Scheduled"
  end

  def outcome_label
    OUTCOME_OPTIONS[outcome] || "-"
  end

  def discharge_destination_label
    DISCHARGE_DESTINATION_OPTIONS[discharge_destination] || "-"
  end

  def to_s
    "#{patient} (#{effective_admission_date || 'date not set'} - #{discharge_date || 'in hospital'})"
  end

  # Builds (and saves) a fresh "requested" reservation from this one, for the
  # common "patient needs to be rebooked" workflow. Actuals, discharge info,
  # admin confirmation, and surgery links intentionally do not carry over;
  # the diagnoses at admission do, since altocumulus keeps those in their own
  # table rather than a single string column.
  def rebook(scheduled_admission_date:)
    copy = dup
    copy.admission_date = nil
    copy.discharge_date = nil
    copy.outcome = nil
    copy.discharge_destination = nil
    copy.deleted_at = nil
    copy.reservation_status = "requested"
    copy.admin_status = "unconfirmed"
    copy.submitted_on = Date.current
    copy.scheduled_admission_date = scheduled_admission_date
    copy.hospitalization_diagnoses_attributes =
      active_hospitalization_diagnoses.map { |hd| { diagnosis_id: hd.diagnosis_id } }
    copy.save
    copy
  end

  private

    def reset_admin_status_for_non_admin_update
      self.admin_status = "unconfirmed"
    end

    def capture_patient_snapshot
      unless patient
        self.patient_name_snapshot = nil
        self.patient_age_snapshot = nil
        self.patient_sex_snapshot = nil
        return
      end

      self.patient_name_snapshot = patient.name
      self.patient_age_snapshot = patient.age
      self.patient_sex_snapshot = patient.sex
    end

    # dependent: :nullify unlinks the surgeries with a single update_all, which
    # skips callbacks and so leaves them missing from the audit log. Saving each
    # record instead keeps the audit trail; validations stay skipped to match
    # what :nullify did, so an already-invalid surgery cannot block the destroy.
    def unlink_surgeries
      surgeries.each do |surgery|
        surgery.hospitalization_id = nil
        surgery.save!(validate: false)
      end
    end

    def diagnosis_ids_in_use
      active_hospitalization_diagnoses.filter_map(&:diagnosis_id)
    end

    def must_have_at_least_one_diagnosis
      return if diagnosis_ids_in_use.any?

      errors.add(:hospitalization_diagnoses, :must_include_at_least_one_diagnosis)
    end

    def no_duplicate_diagnoses
      ids = diagnosis_ids_in_use
      return if ids.uniq.size == ids.size

      errors.add(:hospitalization_diagnoses, :no_duplicate_diagnoses)
    end

    def discharge_date_on_or_after_admission_date
      return if discharge_date.blank? || admission_date.blank?
      return if discharge_date >= admission_date

      errors.add(:discharge_date, :must_be_on_or_after_admission_date)
    end

    def outcome_required_when_discharged
      return if discharge_date.blank?
      return if outcome.present?

      errors.add(:outcome, :blank)
    end

    def discharge_fields_require_discharge_date
      return if discharge_date.present?

      errors.add(:outcome, :requires_discharge_date) if outcome.present?
      if discharge_destination.present?
        errors.add(:discharge_destination, :requires_discharge_date)
      end
    end

    def admission_date_or_scheduled_admission_date_required
      return if admission_date.present? || scheduled_admission_date.present?

      errors.add(:admission_date, :or_scheduled_admission_date_required)
    end

    # scheduled_admission_date, admission_date, and discharge_date all mean
    # "undecided" when left blank, but a string that fails to parse into a
    # date (e.g. a typo) should surface as an error rather than silently
    # becoming nil. Comparing the raw pre-cast value against the cast value
    # tells the two cases apart.
    def valid_date_values
      %i[scheduled_admission_date admission_date discharge_date].each do |field|
        raw = public_send("#{field}_before_type_cast")
        errors.add(field, :not_a_valid_date) if raw.present? && public_send(field).nil?
      end
    end

    # Which field carries the "when" of this hospitalization for error
    # reporting: the actual admission_date once set, otherwise the scheduled
    # one during the reservation stage.
    def effective_admission_date_field
      admission_date.present? ? :admission_date : :scheduled_admission_date
    end

    def no_overlapping_hospitalization_period
      return if patient_id.blank? || effective_admission_date.blank?

      scope = Hospitalization.where(patient_id: patient_id)
      scope = scope.where.not(id: id) if persisted?
      conflict = scope.where(
        "(:end_date IS NULL OR COALESCE(admission_date, scheduled_admission_date) <= :end_date) AND (discharge_date IS NULL OR discharge_date >= :start_date)",
        start_date: effective_admission_date, end_date: discharge_date
      ).exists?

      errors.add(effective_admission_date_field, :overlaps_another_hospitalization) if conflict
    end

    def linked_surgeries_must_remain_within_period
      return if effective_admission_date.blank?

      dates = linked_surgeries.filter_map(&:surgery_date)
      return if dates.empty?

      if dates.any? { |date| date < effective_admission_date }
        errors.add(effective_admission_date_field, :must_include_linked_surgeries_within_period)
      end

      if discharge_date.present? && dates.any? { |date| date > discharge_date }
        errors.add(:discharge_date, :must_include_linked_surgeries_within_period)
      end
    end

    def linked_surgeries_must_belong_to_same_patient
      return if patient_id.blank?
      return if linked_surgeries.all? { |surgery| surgery.patient_id == patient_id }

      errors.add(:patient_id, :must_match_patient_of_linked_surgeries)
    end

    def reset_linked_surgeries_memo
      @linked_surgeries = nil
    end

    # An earlier validation pass may have cached this association (a new record
    # caches an empty list), so re-read it once per validation run and share
    # that read between both validations above.
    def linked_surgeries
      @linked_surgeries ||= persisted? ? surgeries.reload.to_a : surgeries.to_a
    end
end
