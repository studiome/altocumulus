# Columns whose rows are Surgery records (operations calendar, weekly PDF).
# `includes` lists what each builder reads so a screen can preload exactly the
# columns it shows.
module LedgerColumns
  module SurgeryColumns
    extend Cells

    class << self
      # The hospitalization a surgery is part of, unless it was discarded.
      def hospitalization_of(surgery)
        hospitalization = surgery.hospitalization
        hospitalization unless hospitalization&.deleted?
      end

      def all
        @all ||= [
          column(:time_slot, 56, min: 44, css_class: "whitespace-nowrap") { |surgery, _|
            slot = if surgery.regular_slot?
              surgery.slot_number ? I18n.t("surgery_schedules.index.slot_number_label", number: surgery.slot_number) : dash
            else
              surgery.slot_category_label
            end
            cell(segment(surgery.start_time_display, :mono), segment(slot, :secondary))
          },
          column(:admission_dates, 66, min: 56, includes: [ :hospitalization ]) { |surgery, _|
            admission_dates_cell(hospitalization_of(surgery))
          },
          column(:patient, 108, min: 80, flex: 1, css_class: "ledger-patient", includes: [ :patient ]) { |surgery, context|
            patient_cell(surgery, context)
          },
          column(:age_sex, 46, min: 36, includes: [ :patient ]) { |surgery, _|
            age_sex_cell(surgery.patient, surgery.surgery_date)
          },
          column(:diagnosis_procedure, 170, min: 150, flex: 2, includes: [ { patient_diagnoses: :diagnosis }, { surgery_procedure_selections: :surgery_procedure } ]) { |surgery, _|
            cell(segment(surgery.diagnosis_names_display, :secondary),
                 segment(surgery.display_procedure_name, :primary))
          },
          column(:operator_assistant, 80, min: 60, css_class: "ledger-operator") { |surgery, _|
            cell(segment(surgery.operator_name.presence || dash, :primary), optional(surgery.assistant_name))
          },
          column(:duration_anesthesia, 62, min: 44, css_class: "whitespace-nowrap") { |surgery, _|
            hours = surgery.duration_hours
            cell(segment(hours.present? ? I18n.t("surgeries.labels.duration_value", hours: hours) : dash, :primary),
                 optional(surgery.anesthesia_method))
          },
          column(:team, 80, min: 60, flex: 2, includes: [ { team: TEAM_INCLUDES }, { hospitalization: { team: TEAM_INCLUDES } } ]) { |surgery, _|
            team_cell(surgery.effective_team, surgery.team_members_display, undecided: surgery.effective_team_undecided?)
          },
          column(:category, 100, min: 90, flex: 3, includes: [ :department, :surgery_location, :performing_department, :surgical_device,
                                              { hospitalization: :source_department } ]) { |surgery, _|
            hospitalization = hospitalization_of(surgery)
            cell(scheduling_segments(surgery, hospitalization), placement_segments(surgery, hospitalization))
          },
          column(:reservation, 80, min: 60, flex: 1, includes: [ { hospitalization: [ :reservation_doctor, :created_by ] } ]) { |surgery, _|
            reservation_cell(hospitalization_of(surgery))
          },
          column(:referral_adl, 90, min: 70, flex: 1.5, includes: [ :hospitalization ]) { |surgery, context|
            hospitalization = hospitalization_of(surgery)
            lookup = context.referral_lookup
            referral_adl_cell(hospitalization ? hospitalization.referred_from : lookup&.referred_from_for(surgery),
                              hospitalization ? hospitalization.adl : lookup&.adl_for(surgery))
          },
          column(:status, 70, min: 56, flex: 1, includes: [ :hospitalization ]) { |surgery, _|
            status_cell(hospitalization_of(surgery))
          }
        ].freeze
      end

      private

        def column(key, width, min:, **options, &builder)
          LedgerColumn.new(subject: :surgery, key: key, width: width, min_width: min, **options, &builder)
        end

        # Upper part: emergency or elective, emergency admission, the slot
        # category (with partner department / backup intervention) and an
        # off-slot marker for cases that do not sit in a regular slot.
        def scheduling_segments(surgery, hospitalization)
          segments = [ segment(surgery.scheduling_type_label, surgery.emergency? ? :emergency : :scheduling) ]
          segments << emergency_admission_segment(hospitalization)
          return segments if surgery.regular_slot?

          if surgery.off_slot?
            segments << segment(slot_category_text(surgery, surgery.department&.name), :off_slot)
          else
            details = [ surgery.department&.name, surgery.backup_intervention_label ]
            segments << segment(slot_category_text(surgery, *details), :partner_department)
            segments << segment(I18n.t("ledger_columns.off_slot_marker"), :off_slot)
          end
          segments
        end

        def slot_category_text(surgery, *details)
          details = details.compact_blank
          return surgery.slot_category_label if details.empty?

          I18n.t("ledger_columns.with_detail", label: surgery.slot_category_label, detail: details.join(I18n.t("common.list_separator")))
        end

        # Lower part: where it happens and what it involves.
        def placement_segments(surgery, hospitalization)
          [ location_segment(surgery), transfer_segment(hospitalization),
            (segment(surgery.surgical_device.name, :device) if surgery.surgical_device) ]
        end

        def location_segment(surgery)
          location = surgery.surgery_location&.name
          performing = surgery.performing_department&.name
          text = if location.present? && performing.present?
            I18n.t("ledger_columns.with_detail", label: location, detail: performing)
          elsif performing.present?
            I18n.t("ledger_columns.performed_by", department: performing)
          else
            location
          end
          text.present? ? segment(text, :location) : nil
        end
    end
  end
end
