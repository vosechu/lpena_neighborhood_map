class Api::HousesController < ApplicationController
  before_action :authorize_resource

  def index
    @houses = House.includes(residents: :user)
    render json: @houses.map { |house| HouseSerializer.new(house, current_user: current_user).as_json }
  end

  private

  def authorize_resource
    authorize! :read, House
  end
end
