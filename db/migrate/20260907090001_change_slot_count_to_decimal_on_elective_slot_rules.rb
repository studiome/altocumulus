class ChangeSlotCountToDecimalOnElectiveSlotRules < ActiveRecord::Migration[8.1]
  def up
    change_column :elective_slot_rules, :slot_count, :decimal, precision: 4, scale: 1
  end

  def down
    change_column :elective_slot_rules, :slot_count, :integer
  end
end
