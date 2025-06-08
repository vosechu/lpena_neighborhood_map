class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :model_type, null: false
      t.bigint :model_id, null: false
      t.string :action, null: false  # 'create', 'update', 'destroy', 'hide'
      t.json :changes  # Will store old and new values
      t.references :user, foreign_key: true  # Who made the change
      t.string :user_type, default: 'User'  # For polymorphic support if needed later
      
      t.timestamps
    end

    add_index :audit_logs, [:model_type, :model_id]
    add_index :audit_logs, :created_at
    add_index :audit_logs, :user_id
  end
end