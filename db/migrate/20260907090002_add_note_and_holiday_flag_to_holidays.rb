class AddNoteAndHolidayFlagToHolidays < ActiveRecord::Migration[8.1]
  def change
    add_column :holidays, :note, :text
    add_column :holidays, :holiday, :boolean, null: false, default: true
  end
end
