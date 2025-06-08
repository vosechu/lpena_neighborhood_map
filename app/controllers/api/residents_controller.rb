class Api::ResidentsController < ApplicationController
  before_action :set_resident, only: [:show, :update, :destroy, :hide]
  before_action :authorize_resource
  before_action :set_current_user_for_audit

  def index
    authorize! :read, Resident
    
    @residents = if params[:orphaned] == 'true'
                   Resident.visible.includes(:house).where(house: nil)
                 else
                   Resident.visible.includes(:house)
                 end
    
    @residents = @residents.where('display_name ILIKE ? OR official_name ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    render json: @residents.map { |resident| ResidentSerializer.new(resident).as_json.merge(house: resident.house ? { id: resident.house.id, address: "#{resident.house.street_number} #{resident.house.street_name}" } : nil) }
  end

  def show
    render json: ResidentSerializer.new(@resident).as_json
  end

  def create
    authorize! :create, Resident
    
    @resident = Resident.new(resident_params)
    @resident.first_seen_at = Time.current
    
    # Log the creation attempt for audit purposes
    Rails.logger.info "User #{current_user&.id} (#{current_user&.email}) creating new resident"
    
    if @resident.save
      Rails.logger.info "User #{current_user&.id} successfully created resident #{@resident.id}"
      render json: ResidentSerializer.new(@resident).as_json, status: :created
    else
      Rails.logger.warn "User #{current_user&.id} failed to create resident: #{@resident.errors.full_messages}"
      render json: { errors: @resident.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Log the update attempt for audit purposes
    Rails.logger.info "User #{current_user&.id} (#{current_user&.email}) updating resident #{@resident.id}"

    if @resident.update(resident_params)
      # Log successful update with changed fields
      changed_fields = @resident.previous_changes.keys
      Rails.logger.info "User #{current_user&.id} successfully updated resident #{@resident.id}. Changed fields: #{changed_fields.join(', ')}"

      render json: ResidentSerializer.new(@resident).as_json
    else
      Rails.logger.warn "User #{current_user&.id} failed to update resident #{@resident.id}: #{@resident.errors.full_messages}"
      render json: { errors: @resident.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @resident
    
    # Only allow destroying residents that were manually added (not from PCPAO import)
    if @resident.last_import_at.nil?
      Rails.logger.info "User #{current_user&.id} (#{current_user&.email}) deleting resident #{@resident.id}"
      @resident.destroy
      head :no_content
    else
      Rails.logger.warn "User #{current_user&.id} attempted to delete imported resident #{@resident.id}"
      render json: { error: 'Cannot delete imported residents. Use hide instead.' }, status: :forbidden
    end
  end

  def hide
    authorize! :manage, @resident
    
    Rails.logger.info "User #{current_user&.id} (#{current_user&.email}) hiding resident #{@resident.id}"
    @resident.hide!
    head :no_content
  end

  private

  def set_resident
    @resident = Resident.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Resident not found' }, status: :not_found
  end

  def authorize_resource
    case action_name
    when 'index'
      authorize! :read, Resident
    when 'show'
      authorize! :read, @resident
    when 'create'
      authorize! :create, Resident
    when 'update'
      authorize! :manage, @resident
    when 'destroy'
      authorize! :destroy, @resident
    when 'hide'
      authorize! :manage, @resident
    end
  end

  def set_current_user_for_audit
    # Set current user for audit logging - this works with the authentication system
    Thread.current[:current_user] = current_user
  end

  def resident_params
    params.require(:resident).permit(
      :display_name, :homepage, :phone, :email, :skills, :comments, :birthdate,
      :hide_display_name, :hide_email, :hide_phone, :hide_birthdate,
      :house_id, :official_name
    )
  end
end
