class Api::ResidentsController < ApplicationController
  before_action :set_resident, only: [:show, :update]
  before_action :authorize_resource

  def index
    @residents = Resident.all.includes(:house)
    render json: @residents.map { |resident| ResidentSerializer.new(resident).as_json }
  end

  def show
    render json: ResidentSerializer.new(@resident).as_json
  end

  def update
    if ResidentUpdateService.update_resident(@resident, resident_params, current_user)
      render json: @resident
    else
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
    when 'update'
      authorize! :manage, @resident
    end
  end

  def resident_params
    params.require(:resident).permit(:display_name, :homepage, :phone, :email, :skills, :comments)
  end
end
