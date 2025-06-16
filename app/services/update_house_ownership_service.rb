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
    current_owners = @house.residents.not_moved_out.order(:created_at).pluck(:official_name)
    new_owners = [ @owner1, @owner2 ].compact

    # Normalize names only for comparison
    normalized_current = current_owners.map { |name| name.strip.upcase }.sort
    normalized_new = new_owners.map { |name| name.strip.upcase }.sort

    normalized_current != normalized_new
  end

  def mark_current_residents_as_moved_out
    @house.residents.not_moved_out.each do |resident|
      resident.update!(moved_out_at: @current_time)
      @changes[:residents_removed] << resident
    end
  end

  def create_new_residents
    # Create first owner
    resident = create_resident(@owner1)
    @changes[:residents_added] << resident

    # Create second owner if present
    if @owner2.present?
      resident = create_resident(@owner2)
      @changes[:residents_added] << resident
    end
  end

  def create_resident(name)
    @house.residents.create!(
      official_name: name,  # Store the exact value from the city
      first_seen_at: @current_time
    )
  end
end
