class CreateAccessLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :access_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.string :event, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :last_url

      t.timestamps
    end
    add_index :access_logs, :created_at
  end
end
