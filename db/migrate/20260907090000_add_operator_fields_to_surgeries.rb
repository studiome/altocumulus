class AddOperatorFieldsToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_column :surgeries, :operator_name, :string
    add_column :surgeries, :assistant_name, :string
    add_column :surgeries, :operation_order, :integer
  end
end
