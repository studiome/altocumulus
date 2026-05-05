class RenameSurgeryDiagnosesToSurgeryDiagnosisLinks < ActiveRecord::Migration[8.1]
  def up
    rename_table :surgery_diagnoses, :surgery_diagnosis_links
  end

  def down
    rename_table :surgery_diagnosis_links, :surgery_diagnoses
  end
end
