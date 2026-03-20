class AddHospitalIdIndexAndNormalizeSurgeryDurationHours < ActiveRecord::Migration[8.1]
  def up
    add_index :patients, :hospital_id, unique: true

    execute <<~SQL
      UPDATE surgeries
      SET duration_hours = duration_hours / 60.0
      WHERE duration_hours IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE surgeries
      SET duration_hours = duration_hours * 60.0
      WHERE duration_hours IS NOT NULL
    SQL

    remove_index :patients, :hospital_id
  end
end
