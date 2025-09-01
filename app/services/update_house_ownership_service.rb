require 'set'

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

    categorize_name_changes

    ActiveRecord::Base.transaction do
      if @complete_change
        # Complete ownership change - mark ALL residents as moved out
        mark_all_residents_as_moved_out
      else
        # Partial ownership change - only mark specific official residents
        mark_specific_residents_as_moved_out(@leaving_names)
      end

      create_arriving_residents if @arriving_names.any?
    end

    # Send house transition notification if there were changes
    if @changes[:residents_added].any? || @changes[:residents_removed].any?
      ResidentMailer.house_transition_notification(@house, @changes).deliver_later
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

  def categorize_name_changes
    current_names = current_owner_names.to_set
    new_names = new_owner_names.to_set

    @staying_names = current_names.intersection(new_names)    # names in both lists
    @leaving_names = current_names.difference(new_names)     # names only in current
    @arriving_names = new_names.difference(current_names)    # names only in new

    @complete_change = @staying_names.empty? && current_names.any? && new_names.any?
  end

  private

  def mark_all_residents_as_moved_out
    # Complete ownership change - all residents (including housemates) are moving out
    @current_residents.each do |resident|
      resident.update!(moved_out_at: @current_time)
      @changes[:residents_removed] << resident
    end
  end

  def mark_specific_residents_as_moved_out(leaving_names)
    # Partial ownership change - only mark residents with specific official names as moved out
    # Keep residents without official names (housemates) and those whose names are staying
    residents_to_remove = @current_owners.select do |resident|
      normalized_name = resident.official_name&.strip&.upcase
      leaving_names.include?(normalized_name)
    end

    residents_to_remove.each do |resident|
      resident.update!(moved_out_at: @current_time)
      @changes[:residents_removed] << resident
    end
  end

  def create_arriving_residents
    @arriving_names.each do |name|
      resident = create_resident(name)
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
