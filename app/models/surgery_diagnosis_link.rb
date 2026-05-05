class SurgeryDiagnosisLink < ApplicationRecord
  belongs_to :surgery
  belongs_to :patient_diagnosis

  validates :patient_diagnosis_id, uniqueness: { scope: :surgery_id }
end
