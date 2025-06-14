# frozen_string_literal: true

class Resident < ApplicationRecord
  belongs_to :house
  belongs_to :user, optional: true

  # Additional fields for import and resident self-management
  # :homepage - string or text, optional, should be a valid URL if present
  # :skills - text, optional, freeform
  # :comments - text, optional, freeform

  validates :homepage, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }, if: -> { homepage.present? }

  # Core data
  validates :official_name, presence: true
  validates :first_seen_at, presence: true
  validates :house, presence: { message: "can't be blank" }

  # Optional personal info
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }, allow_blank: true
  validates :birthdate, format: { with: /\A(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\z/, message: 'must be in MM-DD format' }, allow_blank: true

  # Privacy settings - now using hide_* fields (DB default is false)
  # attribute :hide_email, :boolean
  # attribute :hide_phone, :boolean
  # attribute :hide_birthdate, :boolean
  # attribute :hide_display_name, :boolean

  # Scopes
  scope :current, -> { where(moved_out_at: nil).where('hidden IS NOT TRUE') }
  # Only residents that are not hidden
  scope :visible, -> { where('hidden IS NOT TRUE') }

  def self.ransackable_attributes(auth_object = nil)
    [ 'display_name', 'email', 'id', 'official_name', 'phone', 'birthdate', 'homepage', 'skills', 'comments' ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ 'house', 'user' ]
  end

  def to_s
    display_name.presence || official_name
  end

  # Birthday detection logic
  def birthday_upcoming?(days_ahead = 30)
    return false if birthdate.blank? || hide_birthdate?

    month, day = birthdate.split('-').map(&:to_i)
    return false unless month.between?(1, 12) && day.between?(1, 31)

    today = Date.current
    birthday = Date.new(today.year, month, day)
    birthday = Date.new(today.year + 1, month, day) if birthday < today

    (birthday - today).to_i.between?(0, days_ahead)
  rescue Date::Error
    false
  end

  def formatted_birthdate
    return birthdate if birthdate.blank? || birthdate == '(hidden by user)'

    month, day = birthdate.split('-').map(&:to_i)
    return birthdate unless month.between?(1, 12) && day.between?(1, 31)

    Date.new(2000, month, day).strftime('%B %-d')
  rescue Date::Error
    birthdate
  end
end
