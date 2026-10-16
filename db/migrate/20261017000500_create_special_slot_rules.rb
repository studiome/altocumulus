# Weekly lane counts (列) of a special slot resource: a hybrid room / cath lab
# (SurgeryLocation) or a surgical robot (SurgicalDevice). A case still uses a
# regular slot and additionally occupies one lane of the resource it names, so
# the rule only counts cases per weekday, never minutes. A resource with no
# rule (or only zero counts) is not a special slot resource.
class CreateSpecialSlotRules < ActiveRecord::Migration[8.1]
  def change
    create_table :special_slot_rules do |t|
      t.string :resource_type, null: false
      t.integer :resource_id, null: false
      t.integer :day_of_week, null: false
      t.integer :slot_count, null: false, default: 0
      t.timestamps
    end
    add_index :special_slot_rules, %i[resource_type resource_id day_of_week], unique: true, name: "index_special_slot_rules_on_resource_and_day"
  end
end
