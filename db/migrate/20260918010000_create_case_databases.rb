class CreateCaseDatabases < ActiveRecord::Migration[8.1]
  def change
    create_table :case_databases do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :case_databases, :name, unique: true

    create_table :case_database_fields do |t|
      t.references :case_database, null: false, foreign_key: true
      t.string :label, null: false
      t.string :field_type, null: false
      t.text :options
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :case_database_fields, [ :case_database_id, :label ], unique: true

    create_table :case_database_entries do |t|
      t.references :case_database, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.json :field_values, null: false, default: {}

      t.timestamps
    end
    add_index :case_database_entries, [ :case_database_id, :patient_id ], unique: true
  end
end
