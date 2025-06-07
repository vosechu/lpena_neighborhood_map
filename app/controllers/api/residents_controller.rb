class Api::ResidentsController < ApplicationController
  def update
    @resident = Resident.find(params[:id])
    if @resident.update(resident_params)
      render json: @resident
    else
      Rails.logger.debug { "Resident update failed: #{ @resident.errors.full_messages.join(', ') }" }
      render json: @resident.errors, status: :unprocessable_entity
    end
  end

  private

  def resident_params
    params.require(:resident).permit(
      :display_name,
      :homepage,
      :phone,
      :email,
      :skills,
      :comments,
      :birthdate
    )
  end
end
