# Columns whose rows are Hospitalization records (the examination-admission
# calendar).
module LedgerColumns
  module HospitalizationColumns
    extend Cells

    class << self
      def all
        @all ||= [
          column(:admission_dates, 66, min: 56) { |hospitalization, _| admission_dates_cell(hospitalization) },
          column(:patient, 108, min: 80, css_class: "ledger-patient", includes: [ :patient ]) { |hospitalization, context|
            patient_cell(hospitalization, context)
          },
          column(:age_sex, 46, min: 36, includes: [ :patient ]) { |hospitalization, _|
            age_sex_cell(hospitalization.patient, hospitalization.effective_admission_date)
          },
          column(:diagnosis_procedure_name, 250, min: 150, flex: true, includes: [ { hospitalization_diagnoses: :diagnosis } ]) { |hospitalization, _|
            cell(segment(hospitalization.diagnosis_names_display, :secondary),
                 segment(hospitalization.procedure_name.presence || dash, :primary))
          },
          column(:purpose, 80, min: 60) { |hospitalization, _|
            date = hospitalization.scheduled_procedure_date || hospitalization.scheduled_surgery_date
            cell(segment(Hospitalization.purpose_options[hospitalization.purpose], :primary),
                 optional(date && date_text(date)))
          },
          column(:team, 80, min: 60, includes: [ { team: TEAM_INCLUDES } ]) { |hospitalization, _|
            team_cell(hospitalization.effective_team, hospitalization.team_members_display)
          },
          column(:category, 100, min: 90, flex: true, includes: [ :source_department ]) { |hospitalization, _|
            cell(emergency_admission_segment(hospitalization), transfer_segment(hospitalization))
          },
          column(:reservation, 80, min: 60, includes: [ :reservation_doctor, :created_by ]) { |hospitalization, _|
            reservation_cell(hospitalization)
          },
          column(:referral_adl, 90, min: 70, flex: true) { |hospitalization, _|
            referral_adl_cell(hospitalization.referred_from, hospitalization.adl)
          },
          column(:status, 70, min: 56) { |hospitalization, _| status_cell(hospitalization) }
        ].freeze
      end

      private

        def column(key, width, min:, **options, &builder)
          LedgerColumn.new(subject: :hospitalization, key: key, width: width, min_width: min, **options, &builder)
        end
    end
  end
end
