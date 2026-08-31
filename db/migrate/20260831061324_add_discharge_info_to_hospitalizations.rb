class AddDischargeInfoToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :discharge_date, :date
    add_column :hospitalizations, :outcome, :string
    add_column :hospitalizations, :discharge_destination, :string

    add_index :hospitalizations, [ :patient_id, :admission_date ]
    add_index :hospitalizations, :discharge_date
  end
end
