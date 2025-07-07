class UpdateHouseOwnershipService
  def self.call(house:, owner1:, owner2: nil)
    new(house: house, owner1: owner1, owner2: owner2).call
  end

  def initialize(house:, owner1:, owner2: nil)
    @house = house
    @owner1 = owner1
    @owner2 = owner2
    @current_time = Time.current
    @changes = { residents_added: [], residents_removed: [] }
  end

  def call
    return @changes unless ownership_changed?

    ActiveRecord::Base.transaction do
      mark_current_residents_as_moved_out
      create_new_residents if @owner1.present?
    end

    @changes
  end

  private

  def ownership_changed?
    # Only compare residents with official names (from city data)
    current_owners = @house.residents.not_moved_out.where.not(official_name: nil).order(:created_at).pluck(:official_name)
    new_owners = [ @owner1, @owner2 ].compact

    # Normalize names only for comparison - handle nil/empty values
    normalized_current = current_owners.map { |name| name&.strip&.upcase }.compact.sort
    normalized_new = new_owners.map { |name| name&.strip&.upcase }.compact.sort

    # Log the comparison for debugging
    Rails.logger.debug "Ownership comparison for house #{@house.pcpa_uid}:"
    Rails.logger.debug "  Current owners: #{normalized_current.inspect}"
    Rails.logger.debug "  New owners: #{normalized_new.inspect}"
    Rails.logger.debug "  Changed: #{normalized_current != normalized_new}"

    normalized_current != normalized_new
  end

  def mark_current_residents_as_moved_out
    # AIDEV-NOTE: Up above we only check the residents with official names (from city data).
    # But if all the official names change, then all the extra residents are probably moving out too.
    @house.residents.not_moved_out.each do |resident|
      resident.update!(moved_out_at: @current_time)
      @changes[:residents_removed] << resident
      Rails.logger.info "Marked resident #{resident.id} (#{resident.official_name}) as moved out"
    end
  end

  def create_new_residents
    # Create first owner if present and not empty
    if @owner1.present? && @owner1.strip.present?
      resident = create_resident(@owner1)
      @changes[:residents_added] << resident
      Rails.logger.info "Created new resident: #{resident.official_name}"
    end

    # Create second owner if present and not empty
    if @owner2.present? && @owner2.strip.present?
      resident = create_resident(@owner2)
      @changes[:residents_added] << resident
      Rails.logger.info "Created new resident: #{resident.official_name}"
    end
  end

  def create_resident(name)
    @house.residents.create!(
      official_name: name,  # Store the exact value from the city
      first_seen_at: @current_time
    )
  end
end
