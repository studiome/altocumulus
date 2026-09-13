class AddSlotCategoryAndLocationToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_column :surgeries, :slot_category, :string, default: "regular", null: false
    add_column :surgeries, :target_department, :string
    add_column :surgeries, :location, :string
  end
end
