class HouseSerializer
  def initialize(house, current_user: nil)
    @house = house
    @current_user = current_user
  end

  def as_json(*_args)
    {
      id: @house.id,
      street_number: @house.street_number,
      street_name: @house.street_name,
      city: @house.city,
      state: @house.state,
      zip: @house.zip,
      latitude: @house.latitude,
      longitude: @house.longitude,
      boundary_geometry: @house.boundary_geometry,
      created_at: @house.created_at,
      updated_at: @house.updated_at,
      residents: @house.residents.map do |resident|
        ResidentSerializer.new(resident, current_user: @current_user).as_json
      end
    }
  end
end
