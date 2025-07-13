class House < ApplicationRecord
  has_many :residents, -> { current }
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

  # These are the attributes used by Avo to search for houses
  def self.ransackable_attributes(auth_object = nil)
    [ 'city', 'id', 'street_name', 'street_number', 'zip' ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ 'residents', 'users' ]
  end

  # This is used in Avo to display the house in the list view
  def to_s
    "#{street_number} #{street_name}"
  end

  # Event detection methods
  def events
    events = []
    events.concat(birthday_events) if birthday_events.present?
    events.concat(new_resident_events) if new_resident_events.present?
    events
  end

  def icon_type
    event_count = events.count
    return nil if event_count == 0
    return 'star' if event_count > 1
    events.first[:type]
  end

  private

  def birthday_events
    upcoming_residents = residents.select { |resident| resident.birthday_upcoming? }
    return [] if upcoming_residents.empty?

    [ {
      type: 'birthday',
      icon: '🎂',
      message: birthday_message(upcoming_residents)
    } ]
  end

  def birthday_message(upcoming_residents)
    upcoming_residents.map do |resident|
      "#{resident.display_name} has an upcoming birthday on #{resident.formatted_birthdate}!"
    end.join('<br />')
  end

  def new_resident_events
    new_residents = residents.select do |resident|
      resident.first_seen_at && 30.days.ago <= resident.first_seen_at
    end
    return [] if new_residents.empty?

    [ {
      type: 'new_residents',
      icon: '🎁',
      message: new_residents_message(new_residents)
    } ]
  end

  def new_residents_message(new_residents)
    new_residents.map(&:display_name).join(' and ') + ' recently moved in!'
  end
end
