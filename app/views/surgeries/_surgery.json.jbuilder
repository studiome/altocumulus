json.extract! surgery, :id, :surgery_date, :duration_hours, :anesthesia_method, :patient_id, :operator_name, :assistant_name, :operation_order, :created_at, :updated_at
# `target_department` and `location` keep their pre-master JSON keys (now the
# master's name) so existing API consumers keep working; the ids are new.
json.extract! surgery, :department_id, :surgery_location_id, :surgical_device_id,
              :hospitalization_id, :backup_intervention, :performing_department_id
json.performing_department surgery.performing_department&.name
json.target_department surgery.department&.name
json.location surgery.surgery_location&.name
json.surgical_device surgery.surgical_device&.name
json.procedure_names surgery.procedure_names
json.display_procedure_name surgery.display_procedure_name
json.url surgery_url(surgery, format: :json)
