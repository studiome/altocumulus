class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.string :auditable_type, null: false
      t.integer :auditable_id, null: false
      t.string :action, null: false
      t.string :record_label, null: false
      t.json :change_data, null: false, default: {}

      t.timestamps
    end

    add_index :audit_events, [ :auditable_type, :auditable_id ]
    add_index :audit_events, [ :auditable_type, :action ]
    add_index :audit_events, :created_at
  end
end
