class CreateHospitalizations < ActiveRecord::Migration[8.1]
  def change
    create_table :hospitalizations do |t|
      t.references :patient, null: false, foreign_key: true
      t.date :admission_date
      t.integer :planned_days
      t.text :reason
      t.string :room_preference

      t.timestamps
    end
  end
end
