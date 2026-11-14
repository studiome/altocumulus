# Columns whose rows are Hospitalization records (the examination-admission
# calendar).
module LedgerColumns
  module HospitalizationColumns
    extend Cells

    class << self
      def all
        @all ||= [
          column(:admission_dates, 82, min: 81) { |hospitalization, _| admission_dates_cell(hospitalization) },
          column(:patient, 108, min: 80, flex: 1, css_class: "ledger-patient", includes: [ :patient ]) { |hospitalization, context|
            patient_cell(hospitalization, context)
          },
          column(:age_sex, 46, min: 36, includes: [ :patient ]) { |hospitalization, _|
            age_sex_cell(hospitalization.patient, hospitalization.effective_admission_date)
          },
          column(:diagnosis_procedure_name, 170, min: 150, flex: 2, includes: [ { hospitalization_diagnoses: :diagnosis }, :chemotherapy_protocol ]) { |hospitalization, context|
            # The procedure name, then the protocol (unless the ledger has its
            # own protocol column); a dash only when neither is shown.
            protocol = hospitalization.chemotherapy_protocol&.name unless context.column?(:protocol)
            names = [ hospitalization.procedure_name.presence, protocol ].compact
            cell(segment(hospitalization.diagnosis_names_display, :secondary),
                 (names.presence || [ dash ]).map { |name| segment(name, :primary) })
          },
          column(:protocol, 100, min: 80, includes: [ :chemotherapy_protocol ]) { |hospitalization, _|
            cell(segment(hospitalization.chemotherapy_protocol&.name.presence || dash, :primary))
          },
          column(:purpose, 80, min: 60) { |hospitalization, _|
            date = hospitalization.scheduled_procedure_date || hospitalization.scheduled_surgery_date
            cell(segment(Hospitalization.purpose_options[hospitalization.purpose], :primary),
                 optional(date && date_text(date)))
          },
          column(:team, 80, min: 60, flex: 2, includes: [ { team: TEAM_INCLUDES } ]) { |hospitalization, _|
            team_cell(hospitalization.effective_team, hospitalization.team_members_display, undecided: hospitalization.effective_team_undecided?)
          },
          column(:category, 100, min: 90, flex: 3, includes: [ :source_department ]) { |hospitalization, _|
            cell(emergency_admission_segment(hospitalization), transfer_segment(hospitalization))
          },
          column(:reservation, 84, min: 81, flex: 1, includes: [ :reservation_doctor, :created_by ]) { |hospitalization, _|
            reservation_cell(hospitalization)
          },
          column(:referral_adl, 90, min: 70, flex: 1.5) { |hospitalization, _|
            referral_adl_cell(hospitalization.referred_from, hospitalization.adl)
          },
          column(:status, 70, min: 56, flex: 1) { |hospitalization, _| status_cell(hospitalization) },
          column(:clinical_comment, 140, min: 90, flex: 3) { |hospitalization, _|
            clinical_comment_cell(hospitalization)
          }
        ].freeze
      end

      private

        def column(key, width, min:, **options, &builder)
          LedgerColumn.new(subject: :hospitalization, key: key, width: width, min_width: min, **options, &builder)
        end
    end
  end
end
