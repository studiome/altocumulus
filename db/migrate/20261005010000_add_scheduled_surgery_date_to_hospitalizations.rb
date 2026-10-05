class AddScheduledSurgeryDateToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :scheduled_surgery_date, :date
  end
end
