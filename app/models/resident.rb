class Resident < ApplicationRecord
  belongs_to :house
  belongs_to :user, optional: true

  # Core data
  validates :official_name, presence: true
  validates :first_seen_at, presence: true
  validates :house, presence: { message: "can't be blank" }

  # Optional personal info
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }, allow_blank: true
  validates :birthdate, comparison: { less_than: -> { Date.current } }, allow_nil: true

  # Privacy settings - default to false for safety
  attribute :share_email, :boolean, default: false
  attribute :share_phone, :boolean, default: false
  attribute :share_birthdate, :boolean, default: false
  attribute :share_display_name, :boolean, default: false

  # Scopes
  scope :current, -> { where(last_seen_at: nil) }

  def display_name
    self[:display_name].presence || official_name
  end

  # Returns a hash of shareable information based on privacy settings
  def shareable_info
    {}.tap do |info|
      info[:display_name] = display_name if share_display_name
      info[:email] = email if share_email && email.present?
      info[:phone] = phone if share_phone && phone.present?
      info[:birthdate] = birthdate if share_birthdate && birthdate.present?
      info[:welcomed_on] = welcomed_on if welcomed_on.present?
    end
  end
end
