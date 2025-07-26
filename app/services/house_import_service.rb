class HouseImportService
  def self.call(house_details)
    new(house_details).call
  end

  def initialize(house_details)
    @attrs = house_details['attributes']
    @geometry = house_details['geometry']
  end

  def call
    # Use address-based lookup instead of pcpa_uid since it's not stable
    house = House.find_or_initialize_by(
      street_number: @attrs['STR_NUM'],
      street_name: extract_street_name,
      city: extract_city
    )

    house.assign_attributes(house_attributes(house))

    return house unless house.changed? || house.new_record?

    house.tap(&:save!)
  end

  def house_attributes(house)
    # AIDEV-NOTE: STR_NUM could be 0, so we need to handle that case
    # See: @reference_data/example_house.json for an example of a house
    {
      street_number: @attrs['STR_NUM'],
      street_name: extract_street_name,
      city: extract_city,
      state: 'FL',  # Hardcoded since we only work with Florida properties
      zip: extract_zip,
      latitude: @attrs['LATITUDE'],
      longitude: @attrs['LONGITUDE'],
      boundary_geometry: @geometry  # Store raw GIS JSON for frontend rendering
    }.tap do |attrs|
      # Only set pcpa_uid if it's not already set (since it's not stable)
      attrs[:pcpa_uid] = @attrs['PCPA_UID'] if house.new_record?
    end
  end

  private

  # Extract street name from SITE_ADDR (format: "6573 1st Ave N")
  # by removing the STR_NUM from the SITE_ADDR
  def extract_street_name
    street_number = @attrs['STR_NUM'].to_s
    @attrs['SITE_ADDR'].sub(/^#{street_number}\s+/, '')
  end

  # Extract from SITE_CITY first (format: "St Petersburg,")
  # falling back to extracting from SITE_CITYZIP (format: "St Petersburg, FL 33710")
  def extract_city
    city = @attrs['SITE_CITY']&.delete(',')
    return city if city.present?

    # fallback to SITE_CITYZIP
    @attrs['SITE_CITYZIP']&.split(',')&.first&.strip
  end

  # Extract zip from SITE_CITYZIP (format: "St Petersburg, FL 33710")
  def extract_zip
    @attrs['SITE_CITYZIP']&.split(' ')&.last
  end
end
