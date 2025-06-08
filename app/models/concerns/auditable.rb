module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :model, foreign_key: :model_id, dependent: :destroy
    
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  private

  def log_create
    create_audit_log('create', { 
      'new_values' => auditable_attributes 
    })
  end

  def log_update
    return unless saved_changes.any?
    
    changes_hash = {}
    saved_changes.each do |attr, values|
      next if ['updated_at', 'created_at'].include?(attr)
      changes_hash[attr] = { 'old' => values[0], 'new' => values[1] }
    end
    
    create_audit_log('update', changes_hash) if changes_hash.any?
  end

  def log_destroy
    create_audit_log('destroy', { 
      'old_values' => auditable_attributes 
    })
  end

  def log_hide
    create_audit_log('hide', { 
      'hidden_at' => Time.current,
      'previous_state' => auditable_attributes
    })
  end

  def create_audit_log(action, changes)
    AuditLog.create!(
      model_type: self.class.name,
      model_id: self.id,
      action: action,
      changes: changes,
      user: current_user_for_audit
    )
  end

  def auditable_attributes
    attributes.except('created_at', 'updated_at')
  end

  def current_user_for_audit
    # This will be set in the controller context
    Thread.current[:current_user]
  end
end