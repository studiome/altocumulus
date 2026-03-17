class RenameDurationMinutesToDurationHoursInSurgeries < ActiveRecord::Migration[8.1]
  def change
    rename_column :surgeries, :duration_minutes, :duration_hours
    change_column :surgeries, :duration_hours, :float
  end
end
