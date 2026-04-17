class LinkPatientDiagnosesToDiagnosisMaster < ActiveRecord::Migration[8.1]
  class MigrationDiagnosis < ActiveRecord::Base
    self.table_name = "diagnoses"
  end

  class MigrationPatientDiagnosis < ActiveRecord::Base
    self.table_name = "patient_diagnoses"
  end

  def up
    add_reference :patient_diagnoses, :diagnosis, foreign_key: true

    MigrationDiagnosis.reset_column_information
    MigrationPatientDiagnosis.reset_column_information

    MigrationPatientDiagnosis.find_each do |patient_diagnosis|
      diagnosis = MigrationDiagnosis.find_or_create_by!(name: patient_diagnosis.diagnosis_name)
      patient_diagnosis.update_columns(diagnosis_id: diagnosis.id)
    end

    change_column_null :patient_diagnoses, :diagnosis_id, false
    remove_column :patient_diagnoses, :diagnosis_name, :string
  end

  def down
    add_column :patient_diagnoses, :diagnosis_name, :string

    MigrationDiagnosis.reset_column_information
    MigrationPatientDiagnosis.reset_column_information

    MigrationPatientDiagnosis.find_each do |patient_diagnosis|
      diagnosis_name = MigrationDiagnosis.find_by(id: patient_diagnosis.diagnosis_id)&.name
      patient_diagnosis.update_columns(diagnosis_name: diagnosis_name)
    end

    change_column_null :patient_diagnoses, :diagnosis_name, false
    remove_reference :patient_diagnoses, :diagnosis, foreign_key: true
  end
end
