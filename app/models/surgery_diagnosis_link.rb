class SurgeryDiagnosisLink < ApplicationRecord
  include LiveUpdatable
  include AuditsAssociatedChanges

  audits_associated_changes_to :surgery, foreign_key: :surgery_id

  belongs_to :surgery
  belongs_to :patient_diagnosis

  validates :patient_diagnosis_id, uniqueness: { scope: :surgery_id }

  def live_update_dates
    surgery&.live_update_dates || []
  end

  def live_update_records
    surgery&.live_update_records || []
  end
end
