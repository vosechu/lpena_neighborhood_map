class DataConflictManager
  attr_reader :conflicts

  def initialize
    @conflicts = []
    @resolution_summary = {
      resolved_automatically: 0,
      requires_manual_review: 0,
      total_conflicts: 0
    }
  end

  def detect_and_resolve_house_conflicts(house, new_attributes)
    return unless house.persisted? && house.changed?

    conflicts_for_house = []
    
    # Check for significant address changes
    if address_changed?(house)
      conflict = {
        type: 'address_change',
        house_id: house.id,
        pcpa_uid: house.pcpa_uid,
        old_address: build_address_string(house.street_number_was, house.street_name_was, house.city_was, house.zip_was),
        new_address: build_address_string(house.street_number, house.street_name, house.city, house.zip),
        resolution: 'auto_accept_latest',
        timestamp: Time.current
      }
      conflicts_for_house << conflict
      @resolution_summary[:resolved_automatically] += 1
    end

    # Check for coordinate changes beyond acceptable threshold
    if coordinates_changed_significantly?(house)
      conflict = {
        type: 'coordinate_change',
        house_id: house.id,
        pcpa_uid: house.pcpa_uid,
        old_coordinates: { lat: house.latitude_was, lng: house.longitude_was },
        new_coordinates: { lat: house.latitude, lng: house.longitude },
        distance_moved: calculate_distance(house.latitude_was, house.longitude_was, house.latitude, house.longitude),
        resolution: 'auto_accept_latest',
        timestamp: Time.current
      }
      conflicts_for_house << conflict
      @resolution_summary[:resolved_automatically] += 1
    end

    if conflicts_for_house.any?
      @conflicts.concat(conflicts_for_house)
      @resolution_summary[:total_conflicts] += conflicts_for_house.length
      log_conflicts(conflicts_for_house)
    end

    conflicts_for_house
  end

  def detect_ownership_conflicts(house, new_owner1, new_owner2)
    current_residents = house.residents.current
    return [] if current_residents.empty?

    current_owners = current_residents.pluck(:official_name).sort
    new_owners = [new_owner1, new_owner2].compact.sort

    return [] if current_owners == new_owners

    conflict = {
      type: 'ownership_change',
      house_id: house.id,
      pcpa_uid: house.pcpa_uid,
      address: build_address_string(house.street_number, house.street_name, house.city, house.zip),
      old_owners: current_owners,
      new_owners: new_owners,
      resolution: 'auto_accept_latest',
      timestamp: Time.current
    }

    @conflicts << conflict
    @resolution_summary[:resolved_automatically] += 1
    @resolution_summary[:total_conflicts] += 1
    
    log_conflicts([conflict])
    [conflict]
  end

  def has_conflicts?
    @conflicts.any?
  end

  def summary
    @resolution_summary.merge(
      total_conflicts: @conflicts.length,
      conflicts_by_type: @conflicts.group_by { |c| c[:type] }.transform_values(&:count)
    )
  end

  private

  def address_changed?(house)
    house.street_number_changed? || 
    house.street_name_changed? || 
    house.city_changed? || 
    house.zip_changed?
  end

  def coordinates_changed_significantly?(house, threshold_meters = 10)
    return false unless house.latitude_changed? || house.longitude_changed?
    return false unless house.latitude_was && house.longitude_was

    distance = calculate_distance(
      house.latitude_was, 
      house.longitude_was, 
      house.latitude, 
      house.longitude
    )
    
    distance > threshold_meters
  end

  def calculate_distance(lat1, lon1, lat2, lon2)
    # Haversine formula to calculate distance in meters
    rad_per_deg = Math::PI / 180
    rlat1 = lat1 * rad_per_deg
    rlat2 = lat2 * rad_per_deg
    dlat = rlat2 - rlat1
    dlon = (lon2 - lon1) * rad_per_deg

    a = Math.sin(dlat/2)**2 + Math.cos(rlat1) * Math.cos(rlat2) * Math.sin(dlon/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    6371000 * c # Earth's radius in meters
  end

  def build_address_string(street_number, street_name, city, zip)
    "#{street_number} #{street_name}, #{city}, FL #{zip}"
  end

  def log_conflicts(conflicts)
    conflicts.each do |conflict|
      Rails.logger.warn "DATA CONFLICT DETECTED: #{conflict[:type]} for House ID #{conflict[:house_id]} (PCPA_UID: #{conflict[:pcpa_uid]})"
      Rails.logger.warn "Conflict details: #{conflict.except(:timestamp).to_json}"
    end
  end
end