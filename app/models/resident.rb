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
  validates :birthdate, comparison: { less_than: -> { Date.current } }, allow_nil: true

  # Privacy settings - default to false for safety
  attribute :share_email, :boolean, default: false
  attribute :share_phone, :boolean, default: false
  attribute :share_birthdate, :boolean, default: false
  attribute :share_display_name, :boolean, default: false

  # Scopes
  scope :current, -> { where(last_seen_at: nil).where('hidden IS NOT TRUE') }
  # Only residents that are not hidden
  scope :visible, -> { where('hidden IS NOT TRUE') }

  def display_name
    self[:display_name].presence || official_name
  end
end
