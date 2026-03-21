class CreateDiagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :diagnoses do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :diagnoses, :name, unique: true
  end
end
