class Api::HousesController < ApplicationController
  # GET /api/houses
  def index
    houses = House.includes(:residents).all
    render json: houses.map { |house| HouseSerializer.new(house).as_json }
  end

  # GET /api/houses/:id
  def show
    house = House.includes(:residents).find(params[:id])
    render json: HouseSerializer.new(house).as_json
  end

  # PATCH/PUT /api/houses/:id
  def update
    house = House.find(params[:id])

    if house.update(house_params)
      render json: HouseSerializer.new(house.reload).as_json
    else
      render json: house.errors, status: :unprocessable_entity
    end
  end

  private

  def house_params
    params.require(:house).permit(
      :street_number,
      :street_name,
      :city,
      :state,
      :zip
    )
  end
end
