json.extract! hospitalization, :id, :patient_id, :admission_date, :planned_days, :reason, :room_preference, :created_at, :updated_at
json.diagnosis_names hospitalization.hospitalization_diagnoses.map(&:diagnosis_name)
json.url hospitalization_url(hospitalization, format: :json)
