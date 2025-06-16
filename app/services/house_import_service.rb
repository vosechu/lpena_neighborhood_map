class HouseImportService
  def self.call(house_details)
    new(house_details).call
  end

  def initialize(house_details)
    @attrs = house_details['attributes']
    @geometry = house_details['geometry']
  end

  def call
    house = House.find_or_initialize_by(pcpa_uid: @attrs['PCPA_UID'])

    house.assign_attributes(house_attributes)

    return house unless house.changed? || house.new_record?

    house.tap(&:save!)
  end

  private

  def house_attributes
    {
      street_number: @attrs['SITE_ADDR'].split(' ').first.to_i,
      street_name: @attrs['SITE_ADDR'].split(' ')[1..-1].join(' '),
      city: extract_city,
      state: 'FL',  # Hardcoded since we only work with Florida properties
      zip: extract_zip,
      latitude: @attrs['LATITUDE'],
      longitude: @attrs['LONGITUDE'],
      boundary_geometry: @geometry  # Store raw GIS JSON for frontend rendering
    }
  end

  def extract_city
    # Try SITE_CITY first, falling back to extracting from SITE_CITYZIP
    city = @attrs['SITE_CITY']&.delete(',')
    return city if city.present?

    # Extract from SITE_CITYZIP (format: "St Petersburg, FL 33710")
    @attrs['SITE_CITYZIP']&.split(',')&.first&.strip
  end

  def extract_zip
    # Extract zip from SITE_CITYZIP (format: "St Petersburg, FL 33710")
    @attrs['SITE_CITYZIP']&.split(' ')&.last
  end
end
