class SurgeryDiagnosisLink < ApplicationRecord
  include AuditsAssociatedChanges

  audits_associated_changes_to :surgery, foreign_key: :surgery_id

  belongs_to :surgery
  belongs_to :patient_diagnosis

  validates :patient_diagnosis_id, uniqueness: { scope: :surgery_id }
end
