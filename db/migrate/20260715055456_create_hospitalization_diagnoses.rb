class CreateHospitalizationDiagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :hospitalization_diagnoses do |t|
      t.references :hospitalization, null: false, foreign_key: true
      t.references :diagnosis, null: false, foreign_key: true

      t.timestamps
    end

    add_index :hospitalization_diagnoses, [ :hospitalization_id, :diagnosis_id ], unique: true, name: "index_hosp_diagnoses_on_hosp_id_and_diagnosis_id"
  end
end
