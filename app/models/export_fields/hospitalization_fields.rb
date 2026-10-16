# Export fields whose rows are Hospitalization records.
module ExportFields
  module HospitalizationFields
    extend Values

    class << self
      def all
        @all ||= (leading_fields + shared_fields + trailing_fields).freeze
      end

      private

        def field(key, includes: [], teams: false, &value)
          ExportField.new(subject: :hospitalization, key: key, includes: includes, teams: teams, &value)
        end

        def leading_fields
          [
            field(:hospital_id, includes: [ :patient ]) { |h| h.patient&.hospital_id },
            field(:patient_name, includes: [ :patient ]) { |h| h.patient&.name },
            field(:patient_kana, includes: [ :patient ]) { |h| h.patient&.name_kana },
            field(:age, includes: [ :patient ]) { |h| age_text(h.patient, h.effective_admission_date) },
            field(:sex, includes: [ :patient ]) { |h| sex_text(h.patient) },
            field(:diagnoses, includes: [ { hospitalization_diagnoses: :diagnosis } ]) { |h|
              join_list(h.active_hospitalization_diagnoses.map(&:diagnosis_name))
            }
          ]
        end

        # The fields it has in common with the surgery export.
        def shared_fields
          hospitalization_values.map do |key, reader|
            field(key, includes: Values::HOSPITALIZATION_VALUE_INCLUDES.fetch(key, [])) { |h| reader.call(h) }
          end
        end

        def trailing_fields
          [
            field(:scheduled_procedure_date) { |h| iso(h.scheduled_procedure_date) },
            field(:procedure_name) { |h| h.procedure_name },
            field(:planned_days) { |h| h.planned_days },
            field(:scheduled_surgery_date) { |h| iso(h.scheduled_surgery_date) },
            field(:attending_doctor) { |h| h.attending_doctor },
            field(:ward) { |h| h.ward },
            field(:team, teams: true, includes: [ { team: ExportField::TEAM_INCLUDES } ]) { |h| team_name(h) },
            field(:team_members, teams: true, includes: [ { team: ExportField::TEAM_INCLUDES } ]) { |h| team_members(h) }
          ]
        end
    end
  end
end
