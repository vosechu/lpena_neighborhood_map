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

  # Privacy settings - now using hide_* fields (DB default is false)
  # attribute :hide_email, :boolean
  # attribute :hide_phone, :boolean
  # attribute :hide_birthdate, :boolean
  # attribute :hide_display_name, :boolean

  # Scopes
  scope :current, -> { where(last_seen_at: nil).where('hidden IS NOT TRUE') }
  # Only residents that are not hidden
  scope :visible, -> { where('hidden IS NOT TRUE') }

  # Stub method for Groups.io integration - returns random true/false
  # TODO: Replace with actual Groups.io API integration
  def subscribed?
    # Use deterministic logic based on resident ID to ensure consistency with scope
    (id % 2) == 1
  end

  # Additional scopes for filtering
  scope :subscribed, -> { where('(id % 2) = 1') } # Stub: deterministic "random" based on ID
  scope :new_residents, -> { where(first_seen_at: 30.days.ago..Time.current) }
end
