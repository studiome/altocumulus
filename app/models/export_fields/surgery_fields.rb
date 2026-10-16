# Export fields whose rows are Surgery records. The hospitalization-side
# fields read the surgery's (not discarded) hospitalization.
module ExportFields
  module SurgeryFields
    extend Values

    class << self
      def all
        @all ||= (surgery_fields + hospitalization_fields).freeze
      end

      private

        def field(key, includes: [], teams: false, &value)
          ExportField.new(subject: :surgery, key: key, includes: includes, teams: teams, &value)
        end

        def surgery_fields
          [
            field(:surgery_date) { |s| iso(s.surgery_date) },
            field(:weekday) { |s| weekday(s.surgery_date) },
            field(:start_time) { |s| s.start_time&.strftime("%H:%M") },
            field(:slot_number) { |s| s.slot_number },
            field(:slot_category) { |s| s.slot_category_label },
            field(:scheduling_type) { |s| s.scheduling_type_label },
            field(:hospital_id, includes: [ :patient ]) { |s| s.patient&.hospital_id },
            field(:patient_name, includes: [ :patient ]) { |s| s.patient&.name },
            field(:patient_kana, includes: [ :patient ]) { |s| s.patient&.name_kana },
            field(:age, includes: [ :patient ]) { |s| age_text(s.patient, s.surgery_date) },
            field(:sex, includes: [ :patient ]) { |s| sex_text(s.patient) },
            field(:diagnoses, includes: [ { patient_diagnoses: :diagnosis } ]) { |s|
              join_list(s.patient_diagnoses.map(&:display_name))
            },
            field(:procedures, includes: [ { surgery_procedure_selections: :surgery_procedure } ]) { |s|
              s.procedure_display_names
            },
            field(:surgical_device, includes: [ :surgical_device ]) { |s| s.surgical_device&.name },
            field(:duration_hours) { |s| s.duration_hours },
            field(:anesthesia_method) { |s| s.anesthesia_method },
            field(:operator) { |s| s.operator_name },
            field(:assistant) { |s| s.assistant_name },
            field(:team, teams: true, includes: team_includes) { |s| team_name(s) },
            field(:team_members, teams: true, includes: team_includes) { |s| team_members(s) },
            field(:location, includes: [ :surgery_location ]) { |s| s.surgery_location&.name },
            field(:performing_department, includes: [ :performing_department ]) { |s| s.performing_department&.name },
            field(:partner_department, includes: [ :department ]) { |s| s.department&.name },
            field(:backup_intervention) { |s| s.backup_intervention_label }
          ]
        end

        def team_includes
          [ { team: ExportField::TEAM_INCLUDES }, { hospitalization: { team: ExportField::TEAM_INCLUDES } } ]
        end

        # The hospitalization-side fields shared with the hospitalization
        # export, read through the surgery's hospitalization.
        def hospitalization_fields
          hospitalization_values.map do |key, reader|
            nested = Values::HOSPITALIZATION_VALUE_INCLUDES.fetch(key, []).map { |name| { hospitalization: name } }
            field(key, includes: [ :hospitalization ] + nested) { |s| reader.call(LedgerColumns::SurgeryColumns.hospitalization_of(s)) }
          end
        end
    end
  end
end
