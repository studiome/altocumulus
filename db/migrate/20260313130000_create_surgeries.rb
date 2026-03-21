class CreateSurgeries < ActiveRecord::Migration[8.1]
  def change
    create_table :surgeries do |t|
      t.date :surgery_date
      t.string :procedure
      t.integer :duration_minutes
      t.string :anesthesia_method
      t.references :patient, null: false, foreign_key: true

      t.timestamps
    end
  end
end
