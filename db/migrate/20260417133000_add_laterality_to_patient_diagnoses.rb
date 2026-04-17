class AddLateralityToPatientDiagnoses < ActiveRecord::Migration[8.1]
  def change
    add_column :patient_diagnoses, :laterality, :string, null: false, default: "none"
  end
end
