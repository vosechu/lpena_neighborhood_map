class UpdateHouseOwnershipService
  def self.call(house:, owner1:, owner2: nil)
    new(house: house, owner1: owner1, owner2: owner2).call
  end

  def initialize(house:, owner1:, owner2: nil)
    @house = house
    @owner1 = owner1
    @owner2 = owner2
    @current_time = Time.current
  end

  def call
    return unless ownership_changed?

    ActiveRecord::Base.transaction do
      mark_current_residents_as_moved_out
      create_new_residents if @owner1.present?
    end
  end

  private

  def ownership_changed?
    current_owners = @house.residents.current.order(:created_at).pluck(:official_name)
    new_owners = [ @owner1, @owner2 ].compact

    current_owners.sort != new_owners.sort
  end

  def mark_current_residents_as_moved_out
    @house.residents.current.update_all(last_seen_at: @current_time)
  end

  def create_new_residents
    # Create first owner
    create_resident(@owner1)

    # Create second owner if present
    create_resident(@owner2) if @owner2.present?
  end

  def create_resident(name)
    @house.residents.create!(
      official_name: name,
      first_seen_at: @current_time,
      last_import_at: @current_time
    )
  end
end
