class ApartmentDenylistService
  # AIDEV-NOTE: List of known apartment buildings that should be excluded
  # from the neighborhood map due to multi-family complexity
  DENYLISTED_ADDRESSES = [
    '5900 5th Ave N',
    '5908 5th Ave N'
  ].freeze

  def self.should_skip?(house_details)
    attrs = house_details['attributes']
    return false if attrs['STR_NUM'].blank? || attrs['SITE_ADDR'].blank?

    address = "#{attrs['STR_NUM']} #{extract_street_name(attrs)}"

    # Only match exact addresses (no unit numbers)
    DENYLISTED_ADDRESSES.any? { |denylisted| address.strip == denylisted }
  end

  private

  def self.extract_street_name(attrs)
    # Extract street name from SITE_ADDR (format: "6573 1st Ave N")
    street_number = attrs['STR_NUM'].to_s
    attrs['SITE_ADDR'].sub(/^#{street_number}\s+/, '')
  end
end
