class Api::AuditLogsController < ApplicationController
  def index
    @audit_logs = AuditLog.recent.includes(:user)
    
    # Filter by model if specified
    if params[:model_type].present? && params[:model_id].present?
      @audit_logs = @audit_logs.where(model_type: params[:model_type], model_id: params[:model_id])
    elsif params[:model_type].present?
      @audit_logs = @audit_logs.where(model_type: params[:model_type])
    end
    
    # Paginate results
    @audit_logs = @audit_logs.limit(params[:limit] || 50).offset(params[:offset] || 0)
    
    render json: @audit_logs.map { |log| audit_log_json(log) }
  end

  def show
    @audit_log = AuditLog.find(params[:id])
    render json: audit_log_json(@audit_log)
  end

  private

  def audit_log_json(audit_log)
    {
      id: audit_log.id,
      model_type: audit_log.model_type,
      model_id: audit_log.model_id,
      action: audit_log.action,
      changes: audit_log.changes,
      user_id: audit_log.user_id,
      user_name: audit_log.user_display_name,
      created_at: audit_log.created_at,
      model_instance: audit_log.model_instance ? {
        id: audit_log.model_instance.id,
        display_name: model_display_name(audit_log.model_instance)
      } : nil
    }
  end

  def model_display_name(instance)
    case instance
    when Resident
      instance.display_name || instance.official_name
    when House
      "#{instance.street_number} #{instance.street_name}"
    else
      instance.to_s
    end
  end
end