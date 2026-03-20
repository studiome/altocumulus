class CreateSurgeryProcedures < ActiveRecord::Migration[8.1]
  def change
    create_table :surgery_procedures do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :surgery_procedures, :name, unique: true
  end
end
