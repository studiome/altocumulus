class MakeNameNullableOnHolidays < ActiveRecord::Migration[8.1]
  def up
    change_column_null :holidays, :name, true
  end

  def down
    Holiday.where(name: nil).update_all(name: "")
    change_column_null :holidays, :name, false
  end
end
