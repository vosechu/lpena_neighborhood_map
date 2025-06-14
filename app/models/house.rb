class House < ApplicationRecord
  has_many :residents
  has_many :users, through: :residents

  validates :pcpa_uid, presence: true, uniqueness: true
  validates :street_number, presence: true
  validates :street_name, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :boundary_geometry, presence: true

  def self.ransackable_attributes(auth_object = nil)
    [ 'city', 'id', 'street_name', 'street_number', 'zip' ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ 'residents', 'users' ]
  end

  def to_s
    "#{street_number} #{street_name}"
  end

  # Event detection methods
  def events
    events = []
    events.concat(birthday_events) if has_upcoming_birthdays?
    events.concat(new_resident_events) if has_new_residents?
    events
  end

  def icon_type
    event_count = events.count
    return nil if event_count == 0
    return 'star' if event_count > 1
    events.first[:type]
  end

  def has_upcoming_birthdays?
    visible_residents = residents.respond_to?(:visible) ? residents.visible : residents.select { |r| !r.hidden? }
    visible_residents.any? { |resident| resident.birthday_upcoming? }
  end

  def has_new_residents?
    residents.any? { |resident| resident.first_seen_at && resident.first_seen_at >= 30.days.ago }
  end

  private

  def birthday_events
    current_residents = residents.respond_to?(:current) ? residents.current : residents.select { |r| r.moved_out_at.nil? && !r.hidden? }
    upcoming_residents = current_residents.select { |resident| resident.birthday_upcoming? }
    return [] if upcoming_residents.empty?

    [ {
      type: 'birthday',
      icon: '🎂',
      message: birthday_message(upcoming_residents)
    } ]
  end

  def new_resident_events
    new_residents = residents.select do |resident|
      resident.first_seen_at && resident.first_seen_at >= 30.days.ago
    end
    return [] if new_residents.empty?

    [ {
      type: 'new_residents',
      icon: '🎁',
      message: new_residents_message(new_residents)
    } ]
  end

  def birthday_message(upcoming_residents)
    if upcoming_residents.count == 1
      resident = upcoming_residents.first
      name = resident.display_name.presence || resident.official_name
      "#{name} has an upcoming birthday!"
    else
      "#{upcoming_residents.count} residents have upcoming birthdays!"
    end
  end

  def new_residents_message(new_residents)
    if new_residents.count == 1
      resident = new_residents.first
      name = resident.display_name.presence || resident.official_name
      "#{name} recently moved in!"
    else
      "#{new_residents.count} new residents recently moved in!"
    end
  end
end
