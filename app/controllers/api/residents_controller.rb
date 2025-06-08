class Api::ResidentsController < ApplicationController
  before_action :set_resident, only: [ :show, :update, :destroy, :hide, :unhide ]
  before_action :authorize_resource

  def index
    @residents = Resident.all.includes(:house)
    render json: @residents.map { |resident| ResidentSerializer.new(resident).as_json }
  end

  def show
    render json: ResidentSerializer.new(@resident).as_json
  end

  def create
    @house = House.find(params[:house_id])
    authorize! :manage, @house
    
    @resident = @house.residents.build(resident_params)
    @resident.first_seen_at = Time.current

    # Log the creation attempt for audit purposes
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) creating resident for house #{@house.id}"

    if @resident.save
      Rails.logger.info "User #{current_user.id} successfully created resident #{@resident.id}"
      render json: ResidentSerializer.new(@resident).as_json, status: :created
    else
      Rails.logger.warn "User #{current_user.id} failed to create resident: #{@resident.errors.full_messages}"
      render json: @resident.errors, status: :unprocessable_entity
    end
  end

  def update
    # Log the update attempt for audit purposes
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) updating resident #{@resident.id}"

    if ResidentUpdateService.update_resident(@resident, resident_params)
      # Log successful update with changed fields
      changed_fields = @resident.previous_changes.keys
      Rails.logger.info "User #{current_user.id} successfully updated resident #{@resident.id}. Changed fields: #{changed_fields.join(', ')}"

      render json: ResidentSerializer.new(@resident).as_json
    else
      Rails.logger.warn "User #{current_user.id} failed to update resident #{@resident.id}: #{@resident.errors.full_messages}"
      render json: @resident.errors, status: :unprocessable_entity
    end
  end

  def destroy
    # Only allow deletion of user-created residents
    if @resident.user_created?
      Rails.logger.info "User #{current_user.id} (#{current_user.email}) deleting resident #{@resident.id}"
      @resident.destroy
      Rails.logger.info "User #{current_user.id} successfully deleted resident #{@resident.id}"
      render json: { message: 'Resident deleted successfully' }, status: :ok
    else
      Rails.logger.warn "User #{current_user.id} attempted to delete official resident #{@resident.id}"
      render json: { error: 'Cannot delete residents from official records' }, status: :forbidden
    end
  end

  def hide
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) hiding resident #{@resident.id}"
    
    if @resident.update(hidden: true)
      Rails.logger.info "User #{current_user.id} successfully hid resident #{@resident.id}"
      render json: { message: 'Resident hidden successfully' }, status: :ok
    else
      Rails.logger.warn "User #{current_user.id} failed to hide resident #{@resident.id}: #{@resident.errors.full_messages}"
      render json: @resident.errors, status: :unprocessable_entity
    end
  end

  def unhide
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) unhiding resident #{@resident.id}"
    
    if @resident.update(hidden: false)
      Rails.logger.info "User #{current_user.id} successfully unhid resident #{@resident.id}"
      render json: ResidentSerializer.new(@resident).as_json, status: :ok
    else
      Rails.logger.warn "User #{current_user.id} failed to unhide resident #{@resident.id}: #{@resident.errors.full_messages}"
      render json: @resident.errors, status: :unprocessable_entity
    end
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
      # Authorization is handled in the create method after finding the house
    when 'update', 'destroy', 'hide', 'unhide'
      authorize! :manage, @resident
    end
  end

  def resident_params
    params.require(:resident).permit(
      :official_name, :display_name, :homepage, :phone, :email, :skills, :comments, :birthdate,
      :hide_display_name, :hide_email, :hide_phone, :hide_birthdate
    )
  end
end
