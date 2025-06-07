# frozen_string_literal: true

class Resident < ApplicationRecord
  belongs_to :house
  belongs_to :user, optional: true

  # Additional fields for import and resident self-management
  # :homepage - string or text, optional, should be a valid URL if present
  # :skills - text, optional, freeform
  # :comments - text, optional, freeform

  # Normalize homepage URL before validations run
  before_validation :normalize_homepage_url

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

  # Accept URLs with or without a protocol; prepend https:// when missing
  validates :homepage,
            format: {
              with: /\(?:https?:\/\/)?[\w.-]+\.[a-z]{2,}(?:[\/\w .-]*)*\/?\z/i,
              allow_blank: true,
              message: 'is not a valid URL'
            }

  # Scopes
  scope :current, -> { where(last_seen_at: nil).where('hidden IS NOT TRUE') }
  # Only residents that are not hidden
  scope :visible, -> { where('hidden IS NOT TRUE') }

  private

  # Adds https:// to homepage if the user omitted the scheme
  def normalize_homepage_url
    return if homepage.blank?

    unless homepage[%r{^https?://}i]
      self.homepage = "https://#{homepage}"
    end
  end
end
