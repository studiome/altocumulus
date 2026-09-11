class RenameEmailToLoginIdOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :email, :login_id
    rename_index :users, "index_users_on_email", "index_users_on_login_id"
  end
end
