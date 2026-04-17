class CreatePatientDiagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :patient_diagnoses do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :diagnosis_name, null: false
      t.date :diagnosed_on, null: false

      t.timestamps
    end

    add_index :patient_diagnoses, [ :patient_id, :diagnosed_on ]
  end
end
