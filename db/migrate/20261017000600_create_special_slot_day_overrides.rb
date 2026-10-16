# Per-date lane counts of a special slot resource, replacing the weekly count
# (special_slot_rules) for that one date -- e.g. the hybrid room runs two lanes
# on one particular Thursday. A resource needs no weekly rule to have one.
class CreateSpecialSlotDayOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :special_slot_day_overrides do |t|
      t.string :resource_type, null: false
      t.integer :resource_id, null: false
      t.date :date, null: false
      t.integer :slot_count, null: false
      t.timestamps
    end
    add_index :special_slot_day_overrides, %i[resource_type resource_id date], unique: true, name: "index_special_slot_day_overrides_on_resource_and_date"
    add_index :special_slot_day_overrides, :date
  end
end
