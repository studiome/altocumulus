# Building blocks shared by the surgery and hospitalization column
# definitions: segment/cell constructors and the cells that read the same
# fields of a Hospitalization whichever record the row is (reservation,
# referral/ADL, status, transfer, team).
module LedgerColumns
  module Cells
    # Associations a team cell reads: the terms with their members, so the
    # term covering a date is picked in memory (see Team#term_for).
    TEAM_INCLUDES = { team_terms: :team_term_members }.freeze

    def segment(text, kind = :primary, href: nil, color: nil)
      LedgerColumn::Segment.new(text.to_s, kind, href, color)
    end

    def cell(upper = [], lower = [])
      LedgerColumn::Cell.new(upper: [ upper ].flatten.compact, lower: [ lower ].flatten.compact)
    end

    def dash
      I18n.t("common.none")
    end

    def date_text(date)
      date ? I18n.l(date, format: :default) : dash
    end

    # Segment for a text only when it is present, so blank values leave the
    # part empty instead of printing an empty line.
    def optional(text, kind = :secondary)
      text.present? ? segment(text, kind) : nil
    end

    def unknown_patient_name(record)
      I18n.t("surgeries.labels.unknown_patient_name", id: record.patient_id)
    end

    def patient_cell(record, context)
      patient = record.patient
      name = patient&.name.presence || unknown_patient_name(record)
      cell(optional(patient&.hospital_id, :secondary_mono),
           segment(name, :primary, href: context.href_for(record)))
    end

    def age_sex_cell(patient, date)
      age = patient&.age_on(date)
      cell(segment(age ? I18n.t("ledger_columns.age_value", age: age) : dash, :primary),
           optional(Patient.sex_options[patient&.sex]))
    end

    def team_cell(team, members)
      return cell unless SiteConfig.current.teams_enabled? && team

      cell(segment(team.name, :team, color: team.color), optional(members))
    end

    def admission_dates_cell(hospitalization)
      cell(segment(date_text(hospitalization&.scheduled_admission_date), :primary),
           segment(date_text(hospitalization&.admission_date), :secondary))
    end

    def reservation_cell(hospitalization)
      return cell unless hospitalization

      doctor = hospitalization.reservation_doctor_display
      creator = hospitalization.created_by&.name
      entered_by = creator.present? && creator != doctor ? I18n.t("ledger_columns.entered_by", name: creator) : nil
      cell(optional(hospitalization.submitted_on && date_text(hospitalization.submitted_on), :primary),
           [ optional(doctor, :primary), optional(entered_by) ])
    end

    def referral_adl_cell(referred_from, adl)
      cell(optional(referred_from, :primary), optional(adl))
    end

    def status_cell(hospitalization)
      return cell(segment(I18n.t("ledger_columns.no_hospitalization"), :missing)) unless hospitalization

      cell(optional(Hospitalization.reservation_status_options[hospitalization.reservation_status], :primary),
           optional(Hospitalization.admin_status_options[hospitalization.admin_status]))
    end

    def emergency_admission_segment(hospitalization)
      return nil unless hospitalization&.emergency_admission

      segment(I18n.t("ledger_columns.emergency_admission"), :emergency)
    end

    def transfer_segment(hospitalization)
      return nil unless hospitalization&.transferred?

      text = hospitalization.transfer_status_label
      source = hospitalization.source_department&.name
      text = I18n.t("ledger_columns.with_detail", label: text, detail: source) if source.present?
      segment(text, :transfer)
    end
  end
end
