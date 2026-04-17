class CreateSurgeryDiagnoses < ActiveRecord::Migration[8.1]
  class MigrationSurgery < ActiveRecord::Base
    self.table_name = "surgeries"
  end

  class MigrationSurgeryDiagnosis < ActiveRecord::Base
    self.table_name = "surgery_diagnoses"
  end

  def up
    create_table :surgery_diagnoses do |t|
      t.references :surgery, null: false, foreign_key: true
      t.references :patient_diagnosis, null: false, foreign_key: true

      t.timestamps
    end

    add_index :surgery_diagnoses, [ :surgery_id, :patient_diagnosis_id ], unique: true

    MigrationSurgery.reset_column_information
    MigrationSurgeryDiagnosis.reset_column_information

    MigrationSurgery.where.not(patient_diagnosis_id: nil).find_each do |surgery|
      MigrationSurgeryDiagnosis.create!(
        surgery_id: surgery.id,
        patient_diagnosis_id: surgery.patient_diagnosis_id
      )
    end

    remove_reference :surgeries, :patient_diagnosis, foreign_key: true
  end

  def down
    add_reference :surgeries, :patient_diagnosis, foreign_key: true

    MigrationSurgery.reset_column_information
    MigrationSurgeryDiagnosis.reset_column_information

    MigrationSurgeryDiagnosis.find_each do |join_record|
      surgery = MigrationSurgery.find(join_record.surgery_id)
      next if surgery.patient_diagnosis_id.present?

      surgery.update_columns(patient_diagnosis_id: join_record.patient_diagnosis_id)
    end

    drop_table :surgery_diagnoses
  end
end
