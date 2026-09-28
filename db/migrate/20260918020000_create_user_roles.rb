class CreateUserRoles < ActiveRecord::Migration[8.1]
  def up
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :user_roles, [ :user_id, :role ], unique: true

    execute <<~SQL.squish
      INSERT INTO user_roles (user_id, role, created_at, updated_at)
      SELECT id, role, datetime('now'), datetime('now') FROM users
    SQL

    remove_column :users, :role
  end

  def down
    add_column :users, :role, :string, default: "user", null: false

    execute <<~SQL.squish
      UPDATE users SET role = (
        SELECT CASE
          WHEN EXISTS (SELECT 1 FROM user_roles WHERE user_roles.user_id = users.id AND user_roles.role = 'admin') THEN 'admin'
          WHEN EXISTS (SELECT 1 FROM user_roles WHERE user_roles.user_id = users.id AND user_roles.role = 'data_manager') THEN 'data_manager'
          ELSE 'user'
        END
      )
    SQL

    drop_table :user_roles
  end
end
