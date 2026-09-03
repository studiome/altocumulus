json.extract! patient_diagnosis, :id, :patient_id, :diagnosis_id, :diagnosed_on, :laterality, :created_at, :updated_at
json.diagnosis_name patient_diagnosis.diagnosis_name
json.display_name patient_diagnosis.display_name
json.url patient_patient_diagnosis_url(patient_diagnosis.patient, patient_diagnosis, format: :json)
