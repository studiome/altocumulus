class AddLateralityToSurgeryProcedureSelections < ActiveRecord::Migration[8.1]
  def change
    add_column :surgery_procedure_selections, :laterality, :string, null: false, default: "none"
  end
end
