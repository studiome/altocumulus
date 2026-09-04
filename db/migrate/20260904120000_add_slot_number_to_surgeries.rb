class AddSlotNumberToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_column :surgeries, :slot_number, :integer
    add_index :surgeries, [ :surgery_date, :slot_number ]
  end
end
