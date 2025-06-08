class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :model_type, presence: true
  validates :model_id, presence: true
  validates :action, presence: true, inclusion: { in: %w[create update destroy hide] }
  
  scope :for_model, ->(model) { where(model_type: model.class.name, model_id: model.id) }
  scope :recent, -> { order(created_at: :desc) }
  
  def model_instance
    model_type.constantize.find_by(id: model_id)
  end
  
  def user_display_name
    user&.name || 'System'
  end
end