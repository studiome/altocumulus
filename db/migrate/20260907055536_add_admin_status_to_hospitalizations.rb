class AddAdminStatusToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :admin_status, :string, default: "unconfirmed", null: false
  end
end
