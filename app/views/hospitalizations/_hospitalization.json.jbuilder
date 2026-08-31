json.extract! hospitalization, :id, :patient_id, :admission_date, :planned_days, :reason, :room_preference,
              :discharge_date, :outcome, :discharge_destination, :created_at, :updated_at
json.diagnosis_names hospitalization.hospitalization_diagnoses.map(&:diagnosis_name)
json.status_label hospitalization.status_label
json.length_of_stay hospitalization.length_of_stay
json.url hospitalization_url(hospitalization, format: :json)
