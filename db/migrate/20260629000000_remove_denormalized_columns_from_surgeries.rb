class RemoveDenormalizedColumnsFromSurgeries < ActiveRecord::Migration[8.1]
  def change
    remove_column :surgeries, :procedure, :string
    remove_column :surgeries, :laterality, :string, default: "none", null: false
  end
end
