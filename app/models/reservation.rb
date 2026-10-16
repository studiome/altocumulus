# The unified reservation (入約) form: one object that creates or edits a
# Hospitalization and, when its purpose is surgery, the Surgery that goes with
# it, in a single transaction.
#
# It is a form object, not a record. It owns the two real records and the two
# kinds of multi-row input the form has:
#   * diagnosis rows (diagnosis + laterality) become the hospitalization's
#     diagnoses; for the surgery they also become linked PatientDiagnosis
#     records (the patient's existing one for the same diagnosis and laterality
#     is reused, otherwise one is created);
#   * procedure rows (procedure + laterality, at most 5) become the surgery's
#     procedure selections.
#
# Validation is the models' own (including the site's required fields and the
# purpose-conditional ones); nothing is relaxed. Their errors are merged into
# this object's errors under "hospitalization.<attribute>" /
# "surgery.<attribute>" keys, so a form can show each message next to its
# field and still list them all in a summary (full messages use the real
# models' attribute names, see .human_attribute_name).
#
# A surgery exists only for the purpose "surgery". Attributes for it are
# ignored for any other purpose. Switching an edited reservation away from
# surgery is refused while its surgery exists: the surgery must be deleted from
# its own screen first, never silently.
class Reservation
  include ActiveModel::Model

  HOSPITALIZATION_KEY = "hospitalization".freeze
  SURGERY_KEY = "surgery".freeze

  # One diagnosis / procedure row of the form. `id` is the row's record id once
  # saved (HospitalizationDiagnosis / SurgeryProcedureSelection).
  DiagnosisRow = Struct.new(:id, :diagnosis_id, :laterality, :_destroy, keyword_init: true) do
    def persisted? = id.present?
    def destroyed_in_form? = _destroy.to_s == "1"
    def diagnosis = diagnosis_id.present? ? Diagnosis.find_by(id: diagnosis_id) : nil
  end

  ProcedureRow = Struct.new(:id, :surgery_procedure_id, :laterality, :_destroy, keyword_init: true) do
    def persisted? = id.present?
    def destroyed_in_form? = _destroy.to_s == "1"
    def surgery_procedure = surgery_procedure_id.present? ? SurgeryProcedure.find_by(id: surgery_procedure_id) : nil
  end

  attr_reader :hospitalization, :diagnosis_rows, :procedure_rows

  # A blank reservation for the "new" screen. The prefill values come straight
  # from the query string, so anything unparsable simply leaves a field blank.
  def self.build_new(user: nil, surgery_date: nil, scheduled_admission_date: nil, scheduled_procedure_date: nil, purpose: nil, patient_id: nil)
    reservation = new
    hospitalization = reservation.hospitalization
    hospitalization.purpose = purpose if Hospitalization::PURPOSE_KEYS.include?(purpose)
    hospitalization.scheduled_admission_date = parse_date(scheduled_admission_date)
    hospitalization.scheduled_procedure_date = parse_date(scheduled_procedure_date)
    hospitalization.patient = Patient.find_by(id: patient_id) if patient_id.is_a?(String) || patient_id.is_a?(Integer)
    hospitalization.reservation_doctor = user
    hospitalization.submitted_on = Date.current
    reservation.send(:ensure_surgery) if reservation.surgery_applicable?
    reservation.surgery&.surgery_date = parse_date(surgery_date)
    reservation
  end

  # An existing reservation for editing: the hospitalization with the first
  # linked surgery by date (nil when it has none).
  def self.for_hospitalization(hospitalization)
    surgery = hospitalization.surgeries.includes(surgery_procedure_selections: :surgery_procedure).ascending_by_surgery_date.first
    new(hospitalization: hospitalization, surgery: surgery)
  end

  def self.parse_date(value)
    Date.iso8601(value) if value.is_a?(String)
  rescue Date::Error
    nil
  end

  # Errors are keyed "hospitalization.x" / "surgery.x"; label them like the
  # real attributes.
  def self.human_attribute_name(attribute, options = {})
    scope, name = attribute.to_s.split(".", 2)
    case scope
    when HOSPITALIZATION_KEY then Hospitalization.human_attribute_name(name, options.except(:default))
    when SURGERY_KEY then Surgery.human_attribute_name(name, options.except(:default))
    else super
    end
  end

  # Errors keyed "hospitalization.x" / "surgery.x" read their value from that
  # record (for message interpolation).
  def read_attribute_for_validation(attribute)
    scope, name = attribute.to_s.split(".", 2)
    record = { HOSPITALIZATION_KEY => hospitalization, SURGERY_KEY => surgery }[scope]
    record && record.respond_to?(name) ? record.public_send(name) : nil
  end

  def initialize(hospitalization: nil, surgery: nil)
    super()
    @hospitalization = hospitalization || Hospitalization.new
    @surgery = surgery
    @original_diagnosis_ids = @hospitalization.persisted? ? @hospitalization.hospitalization_diagnoses.map(&:diagnosis_id) : []
    ensure_surgery if surgery_applicable?
    @diagnosis_rows = build_diagnosis_rows
    @procedure_rows = build_procedure_rows
  end

  # The surgery, present only when the purpose is surgery -- or when an edited
  # reservation still has a stored one (which is what the purpose guard needs).
  attr_reader :surgery

  # What the form renders in its surgery section, which exists (hidden) for any
  # purpose so that choosing "surgery" can reveal it.
  def surgery_for_form
    @surgery || (@form_surgery ||= Surgery.new)
  end

  def surgery_applicable?
    hospitalization.purpose == "surgery"
  end

  def persisted?
    hospitalization.persisted?
  end

  # The blank-row-padded lists the form renders.
  def diagnosis_rows_for_form
    diagnosis_rows.presence || [ DiagnosisRow.new(laterality: "none") ]
  end

  def procedure_rows_for_form
    procedure_rows.presence || [ ProcedureRow.new(laterality: "none") ]
  end

  # attrs: { hospitalization: {...}, surgery: {...}, diagnoses: { idx => {...} },
  # procedures: { idx => {...} } } (strings or symbols; Parameters are fine).
  def assign(attrs)
    attrs = indifferent(attrs)

    hospitalization.assign_attributes(attrs[HOSPITALIZATION_KEY]) if attrs[HOSPITALIZATION_KEY].present?
    assign_diagnosis_rows(attrs["diagnoses"]) if attrs.key?("diagnoses")

    if surgery_applicable?
      ensure_surgery
      @surgery.assign_attributes(attrs[SURGERY_KEY]) if attrs[SURGERY_KEY].present?
      assign_procedure_rows(attrs["procedures"]) if attrs.key?("procedures")
    elsif @surgery&.new_record?
      @surgery = nil
    end
    self
  end

  def update(attrs)
    assign(attrs)
    save
  end

  validate :validate_records

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      hospitalization.save!
      if surgery_applicable?
        surgery.hospitalization = hospitalization
        surgery.patient = hospitalization.patient
        surgery.save!
        sync_patient_diagnoses
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    merge_record_errors(e.record)
    errors.add(:base, :not_saved) if errors.empty?
    false
  rescue ActiveRecord::RecordNotUnique
    errors.add(:"hospitalization.hospitalization_diagnoses", :cannot_swap_between_rows)
    false
  end

  def save!
    save || raise(ActiveRecord::RecordInvalid.new(hospitalization))
  end

  # The date a team's term members are previewed for.
  def team_preview_date
    (surgery_applicable? ? surgery_for_form.surgery_date : nil) || hospitalization.scheduled_procedure_date ||
      hospitalization.scheduled_surgery_date || hospitalization.effective_admission_date
  end

  private

    def indifferent(attrs)
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      (attrs || {}).to_h.with_indifferent_access
    end

    def ensure_surgery
      @surgery ||= Surgery.new
    end

    # Rows can arrive as an index-keyed hash (the form), or an array.
    def row_hashes(value)
      list = value.respond_to?(:values) ? value.values : Array(value)
      list.map { |entry| indifferent(entry) }
    end

    def assign_diagnosis_rows(value)
      @diagnosis_rows = row_hashes(value).map do |row|
        DiagnosisRow.new(id: row[:id].presence, diagnosis_id: row[:diagnosis_id].presence,
                         laterality: row[:laterality].presence || "none", _destroy: row[:_destroy])
      end
      hospitalization.hospitalization_diagnoses_attributes = @diagnosis_rows.map do |row|
        { id: row.id, diagnosis_id: row.diagnosis_id, _destroy: row._destroy }.compact
      end
    end

    def assign_procedure_rows(value)
      @procedure_rows = row_hashes(value).map do |row|
        ProcedureRow.new(id: row[:id].presence, surgery_procedure_id: row[:surgery_procedure_id].presence,
                         laterality: row[:laterality].presence || "none", _destroy: row[:_destroy])
      end
      surgery.surgery_procedure_selections_attributes = @procedure_rows.map do |row|
        { id: row.id, surgery_procedure_id: row.surgery_procedure_id, laterality: row.laterality, _destroy: row._destroy }.compact
      end
    end

    def build_diagnosis_rows
      return [] unless hospitalization.persisted?

      hospitalization.hospitalization_diagnoses.map do |hd|
        DiagnosisRow.new(id: hd.id, diagnosis_id: hd.diagnosis_id, laterality: stored_laterality_for(hd.diagnosis_id))
      end
    end

    def build_procedure_rows
      return [] unless @surgery&.persisted?

      @surgery.surgery_procedure_selections.map do |selection|
        ProcedureRow.new(id: selection.id, surgery_procedure_id: selection.surgery_procedure_id, laterality: selection.laterality)
      end
    end

    # The laterality of the patient diagnosis the surgery is linked to for this
    # diagnosis, so editing shows what was entered.
    def stored_laterality_for(diagnosis_id)
      @surgery&.patient_diagnoses&.find { |pd| pd.diagnosis_id == diagnosis_id }&.laterality || "none"
    end

    # ---- validation -------------------------------------------------------

    def validate_records
      prepare_records

      hospitalization.valid?
      surgery.valid? if surgery_applicable?

      merge_record_errors(hospitalization)
      merge_record_errors(surgery) if surgery_applicable?
      validate_row_lateralities
      validate_surgery_can_be_left
    end

    # Brings the two records in step with each other before they are validated
    # or saved (idempotent).
    def prepare_records
      hospitalization.submitted_on ||= Date.current if hospitalization.new_record?
      return unless surgery_applicable?

      ensure_surgery

      surgery.hospitalization = hospitalization
      surgery.patient = hospitalization.patient
      hospitalization.scheduled_surgery_date = surgery.surgery_date
      follow_hospitalization_team
      surgery.performing_department = nil unless surgery.surgery_location&.asks_performing_department?
    end

    # A new surgery starts on the hospitalization's team (the model does the
    # same on create); an existing one follows a team change only while it was
    # still on the hospitalization's previous team.
    def follow_hospitalization_team
      if surgery.new_record?
        surgery.team ||= hospitalization.team
      elsif hospitalization.team_id_changed? && (surgery.team_id.nil? || surgery.team_id == hospitalization.team_id_was)
        surgery.team_id = hospitalization.team_id
      end
    end

    def merge_record_errors(record)
      return if record.nil?

      scope = record.is_a?(Surgery) ? SURGERY_KEY : HOSPITALIZATION_KEY
      record.errors.each do |error|
        attribute = error.attribute
        next if scope == SURGERY_KEY && %i[patient hospitalization].include?(attribute)

        # The surgery date lives on the surgery section of this form.
        key = scope == HOSPITALIZATION_KEY && attribute == :scheduled_surgery_date && surgery_applicable? ? "#{SURGERY_KEY}.surgery_date" : "#{scope}.#{attribute}"
        next if errors.added?(key.to_sym, error.message)

        errors.import(error, attribute: key.to_sym)
      end
    end

    def validate_row_lateralities
      (diagnosis_rows.reject(&:destroyed_in_form?).map(&:laterality) - Lateralizable::LATERALITY_KEYS).each do
        errors.add(:"hospitalization.hospitalization_diagnoses", :invalid)
      end
    end

    def validate_surgery_can_be_left
      return if surgery_applicable? || !@surgery&.persisted?

      errors.add(:"hospitalization.purpose", :cannot_leave_surgery)
    end

    # ---- saving -----------------------------------------------------------

    # Links the surgery to the patient's diagnoses for the form's diagnosis
    # rows. Links to diagnoses that were never part of the reservation (added
    # on the surgery's own screen) are left alone.
    def sync_patient_diagnoses
      rows = diagnosis_rows.reject(&:destroyed_in_form?).select { |row| row.diagnosis_id.present? }
      desired = rows.map { |row| patient_diagnosis_for(row) }
      managed_ids = rows.map { |row| row.diagnosis_id.to_i } | @original_diagnosis_ids
      kept = surgery.patient_diagnoses.reject { |pd| managed_ids.include?(pd.diagnosis_id) }
      surgery.patient_diagnoses = (kept + desired).uniq
    end

    def patient_diagnosis_for(row)
      patient = hospitalization.patient
      existing = patient.patient_diagnoses.find_by(diagnosis_id: row.diagnosis_id, laterality: row.laterality)
      existing || PatientDiagnosis.create!(
        patient: patient, diagnosis_id: row.diagnosis_id, laterality: row.laterality,
        diagnosed_on: hospitalization.submitted_on || Date.current
      )
    end
end
