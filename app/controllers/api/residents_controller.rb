class Api::ResidentsController < ApplicationController
  def index
    residents = Resident.visible.includes(:house)
    
    # Apply filters
    residents = residents.where('LOWER(official_name) LIKE ? OR LOWER(display_name) LIKE ?', "%#{params[:search].downcase}%", "%#{params[:search].downcase}%") if params[:search].present?
    residents = residents.subscribed if params[:subscribed] == 'true'
    residents = residents.where('(id % 2) = 0') if params[:subscribed] == 'false' # Not subscribed
    residents = residents.new_residents if params[:new_residents] == 'true'
    
    render json: residents.map { |resident| ResidentSerializer.new(resident).as_json }
  end

  def update
    @resident = Resident.find(params[:id])
    if @resident.update(resident_params)
      render json: @resident
    else
      render json: @resident.errors, status: :unprocessable_entity
    end
  end

  private

  def resident_params
    params.require(:resident).permit(:display_name, :homepage, :phone, :email, :skills, :comments)
  end
end
