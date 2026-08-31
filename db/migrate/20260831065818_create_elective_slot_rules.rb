class CreateElectiveSlotRules < ActiveRecord::Migration[8.1]
  def change
    create_table :elective_slot_rules do |t|
      t.integer :day_of_week, null: false
      t.integer :slot_count, null: false
      t.integer :slot_duration_minutes, null: false

      t.timestamps
    end
    add_index :elective_slot_rules, :day_of_week, unique: true
  end
end
