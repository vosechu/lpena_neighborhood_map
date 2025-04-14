class Api::HousesController < ApplicationController
  def index
    render file: Rails.root.join('houses.json')
  end
end
