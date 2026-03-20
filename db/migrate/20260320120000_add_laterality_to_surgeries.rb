class AddLateralityToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_column :surgeries, :laterality, :string, null: false, default: "none"
  end
end
