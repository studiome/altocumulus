json.extract! surgery, :id, :surgery_date, :laterality, :procedure, :duration_hours, :anesthesia_method, :patient_id, :created_at, :updated_at
json.display_procedure_name surgery.display_procedure_name
json.url surgery_url(surgery, format: :json)
