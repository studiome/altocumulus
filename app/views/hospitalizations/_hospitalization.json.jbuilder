json.extract! hospitalization, :id, :patient_id, :admission_date, :scheduled_admission_date,
              :reservation_status, :purpose, :planned_days, :reason, :room_preference,
              :ward, :referred_from, :adl, :reservation_doctor, :attending_doctor,
              :submitted_on, :clinical_comment,
              :discharge_date, :outcome, :discharge_destination, :created_at, :updated_at
json.diagnosis_names hospitalization.hospitalization_diagnoses.map(&:diagnosis_name)
json.effective_admission_date hospitalization.effective_admission_date
json.status_label hospitalization.status_label
json.length_of_stay hospitalization.length_of_stay
json.url hospitalization_url(hospitalization, format: :json)
