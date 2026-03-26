class CreateSurgeryProcedureSelections < ActiveRecord::Migration[8.1]
  def up
    create_table :surgery_procedure_selections do |t|
      t.references :surgery, null: false, foreign_key: true
      t.references :surgery_procedure, null: false, foreign_key: true

      t.timestamps
    end

    add_index :surgery_procedure_selections, %i[surgery_id surgery_procedure_id], unique: true, name: "index_surgery_procedure_selections_on_surgery_and_procedure"

    execute <<~SQL.squish
      INSERT INTO surgery_procedure_selections (surgery_id, surgery_procedure_id, created_at, updated_at)
      SELECT surgeries.id, surgery_procedures.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM surgeries
      INNER JOIN surgery_procedures ON surgery_procedures.name = surgeries.procedure
      WHERE surgeries.procedure IS NOT NULL AND surgeries.procedure != ''
    SQL
  end

  def down
    drop_table :surgery_procedure_selections
  end
end