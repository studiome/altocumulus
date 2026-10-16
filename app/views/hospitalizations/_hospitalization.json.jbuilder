json.extract! hospitalization, :id, :patient_id, :admission_date, :scheduled_admission_date, :scheduled_surgery_date,
              :reservation_status, :purpose, :admin_status, :planned_days, :reason, :room_preference,
              :ward, :referred_from, :adl, :attending_doctor,
              :submitted_on, :clinical_comment,
              :discharge_date, :outcome, :discharge_destination,
              :patient_name_snapshot, :patient_age_snapshot, :patient_sex_snapshot,
              :deleted_at, :created_at, :updated_at
json.extract! hospitalization, :emergency_admission, :transfer_status, :source_department_id,
              :reservation_doctor_id, :created_by_id, :scheduled_procedure_date, :procedure_name
json.reservation_doctor hospitalization.reservation_doctor_display
json.diagnosis_names hospitalization.hospitalization_diagnoses.map(&:diagnosis_name)
json.effective_admission_date hospitalization.effective_admission_date
json.status_label hospitalization.status_label
json.length_of_stay hospitalization.length_of_stay
json.days_since_admission hospitalization.days_since_admission
json.url hospitalization_url(hospitalization, format: :json)
