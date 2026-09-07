class AddDeletedAtToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :deleted_at, :datetime
    add_index :hospitalizations, :deleted_at
  end
end
