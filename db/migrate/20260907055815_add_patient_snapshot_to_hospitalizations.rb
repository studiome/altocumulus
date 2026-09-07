class AddPatientSnapshotToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :patient_name_snapshot, :string
    add_column :hospitalizations, :patient_age_snapshot, :integer
    add_column :hospitalizations, :patient_sex_snapshot, :string
  end
end
