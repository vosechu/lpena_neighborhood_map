class User < ApplicationRecord
  has_one :resident
  has_one :house, through: :resident

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
