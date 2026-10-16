class CreateMasterTables < ActiveRecord::Migration[8.1]
  # Admin-editable lists of site vocabulary: departments, the places a surgery
  # is performed, and surgical support devices (see MasterRecord).
  TABLES = %i[departments surgery_locations surgical_devices].freeze

  def change
    TABLES.each do |table|
      create_table table do |t|
        t.string :name, null: false
        t.integer :position, null: false
        t.boolean :active, null: false, default: true
        t.timestamps
      end
      add_index table, :name, unique: true
    end
  end
end
