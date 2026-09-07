class AddOperatorToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :audit_events, :user, null: true, foreign_key: true
    add_column :audit_events, :ip_address, :string
  end
end
