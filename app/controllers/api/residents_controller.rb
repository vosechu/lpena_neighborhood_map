class Api::ResidentsController < ApplicationController
  before_action :set_resident, only: [ :show, :update ]
  before_action :authorize_resource

  def index
    @residents = Resident.current.includes(:house)
    render json: @residents.map { |resident| ResidentSerializer.new(resident).as_json }
  end

  def show
    render json: ResidentSerializer.new(@resident).as_json
  end

  def create
    # Log the creation attempt for audit purposes
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) creating new resident"

    resident = ResidentCreationService.create_resident(resident_params)

    if resident.persisted?
      Rails.logger.info "User #{current_user.id} successfully created resident #{resident.id}"
      render json: ResidentSerializer.new(resident).as_json, status: :created
    else
      Rails.logger.warn "User #{current_user.id} failed to create resident: #{resident.errors.full_messages}"
      render json: resident.errors, status: :unprocessable_entity
    end
  end

  def update
    # Log the update attempt for audit purposes
    Rails.logger.info "User #{current_user.id} (#{current_user.email}) updating resident #{@resident.id}"

    if ResidentUpdateService.update_resident(@resident, resident_params)
      # Log successful update with changed fields
      changed_fields = @resident.previous_changes.keys
      Rails.logger.info "User #{current_user.id} successfully updated resident #{@resident.id}. Changed fields: #{changed_fields.join(', ')}"

      render json: @resident
    else
      Rails.logger.warn "User #{current_user.id} failed to update resident #{@resident.id}: #{@resident.errors.full_messages}"
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
      authorize! :manage, Resident
    when 'update'
      authorize! :manage, @resident
    end
  end

  def resident_params
    params.require(:resident).permit(
      :house_id, :official_name, :display_name, :homepage, :phone,
      :email, :skills, :comments,
      :birthdate, :hide_email, :hide_phone,
      :hide_birthdate, :hide_display_name, :email_notifications_opted_out,
      :hidden)
  end
end
