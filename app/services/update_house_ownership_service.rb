class UpdateHouseOwnershipService
  def initialize(house:, owner1_name:, owner2_name: nil)
    @house = house
    # AIDEV-NOTE: Only compare residents with official names (from city data)
    # There may be other residents without official names, but they're usually
    # doggos or kids, so the city doesn't include their names in the property info.
    @current_residents = Resident.where(house_id: @house.id).not_moved_out
    @current_owners = @current_residents.where.not(official_name: [ nil, '' ]).distinct
    @owner1_name = owner1_name
    @owner2_name = owner2_name
    @current_time = Time.current
    @changes = { residents_added: [], residents_removed: [] }
  end

  def call
    return @changes unless ownership_changed?

    ActiveRecord::Base.transaction do
      mark_current_residents_as_moved_out
      create_new_residents if @owner1_name.present?
    end

    @changes
  end

  def current_owner_names
    @current_owners.map { |owner| owner&.official_name&.strip&.upcase }.compact.sort
  end

  def new_owner_names
    [ @owner1_name, @owner2_name ].compact.map { |name| name&.strip&.upcase }.reject(&:blank?).sort
  end

  def ownership_changed?
    current_owner_names != new_owner_names
  end

  private

  def mark_current_residents_as_moved_out
    # AIDEV-NOTE: Up above we only check the residents with official names (from city data).
    # But if all the official names change, then all the extra residents are probably moving out too.
    @current_residents.each do |resident|
      resident.update!(moved_out_at: @current_time)
      @changes[:residents_removed] << resident
    end
  end

  def create_new_residents
    # Create first owner if present and not empty
    if @owner1_name.present? && @owner1_name.strip.present?
      resident = create_resident(@owner1_name)
      @changes[:residents_added] << resident
    end

    # Create second owner if present and not empty
    if @owner2_name.present? && @owner2_name.strip.present?
      resident = create_resident(@owner2_name)
      @changes[:residents_added] << resident
    end
  end

  def create_resident(name)
    raise ArgumentError, 'official_name is required for imported residents' if name.blank?
    @house.residents.create!(
      official_name: name,  # Store the exact value from the city
      first_seen_at: @current_time
    )
  end
end
