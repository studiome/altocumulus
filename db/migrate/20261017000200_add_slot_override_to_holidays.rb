# A comment-only Holiday row (holiday: false) may override the weekday's slot
# rule for its date: its own slot_count (like ElectiveSlotRule#slot_count) and,
# optionally, its own slot_duration_minutes. Closed days never carry one.
class AddSlotOverrideToHolidays < ActiveRecord::Migration[8.1]
  def change
    add_column :holidays, :slot_count, :decimal, precision: 4, scale: 1
    add_column :holidays, :slot_duration_minutes, :integer
  end
end
