class AddSchedulingToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_column :surgeries, :scheduling_type, :string, null: false, default: "elective"
    add_column :surgeries, :start_time, :time
    add_index :surgeries, [ :surgery_date, :scheduling_type ]
  end
end
