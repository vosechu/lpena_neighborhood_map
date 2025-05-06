class Api::HousesController < ApplicationController
  def index
    houses = House.includes(:residents).all
    render json: houses.map { |house| HouseSerializer.new(house).as_json }
  end
end
