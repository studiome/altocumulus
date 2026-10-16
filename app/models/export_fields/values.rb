# Value helpers shared by the surgery and hospitalization export fields.
# Everything here is nil-safe (a missing patient, hospitalization, date or
# master row gives nil, never an error) and returns plain text.
module ExportFields
  module Values
    def iso(date)
      date&.iso8601
    end

    def join_list(items)
      items.compact_blank.join(I18n.t("common.list_separator")).presence
    end

    def yes_no(flag)
      flag ? I18n.t("export_fields.yes") : I18n.t("export_fields.no")
    end

    def weekday(date)
      date && I18n.t("date.abbr_day_names")[date.wday]
    end

    def age_text(patient, date)
      date && patient&.age_on(date)
    end

    def sex_text(patient)
      Patient.sex_options[patient&.sex]
    end

    def transfer_text(hospitalization)
      return nil unless hospitalization&.transferred?

      hospitalization.transfer_status_label
    end

    def team_name(record)
      return nil unless SiteConfig.current.teams_enabled?

      record.effective_team&.name || (I18n.t("teams.undecided_badge") if record.effective_team_undecided?)
    end

    def team_members(record)
      SiteConfig.current.teams_enabled? ? record.team_members_display : nil
    end

    # Fields every hospitalization-side export reads, whichever record the
    # row is: `hospitalization` is the Hospitalization (nil for a surgery
    # without one). Returns {key => lambda(hospitalization)}.
    def hospitalization_values
      {
        scheduled_admission_date: ->(h) { iso(h&.scheduled_admission_date) },
        admission_date: ->(h) { iso(h&.admission_date) },
        discharge_date: ->(h) { iso(h&.discharge_date) },
        emergency_admission: ->(h) { h && yes_no(h.emergency_admission) },
        transfer_status: ->(h) { transfer_text(h) },
        source_department: ->(h) { h&.source_department&.name },
        referred_from: ->(h) { h&.referred_from },
        adl: ->(h) { h&.adl },
        reservation_doctor: ->(h) { h&.reservation_doctor_display },
        created_by: ->(h) { h&.created_by&.name },
        submitted_on: ->(h) { iso(h&.submitted_on) },
        reservation_status: ->(h) { h && Hospitalization.reservation_status_options[h.reservation_status] },
        purpose: ->(h) { h && Hospitalization.purpose_options[h.purpose] },
        clinical_comment: ->(h) { h&.clinical_comment }
      }
    end

    # Associations (relative to a Hospitalization) each of those reads.
    HOSPITALIZATION_VALUE_INCLUDES = {
      source_department: [ :source_department ],
      reservation_doctor: [ :reservation_doctor ],
      created_by: [ :created_by ]
    }.freeze
  end
end
