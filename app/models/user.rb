class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  has_one :resident
  has_one :house, through: :resident

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: %w[admin user] }

  # Role-based authorization
  def admin?
    role == 'admin'
  end

  def user?
    role == 'user'
  end

  def self.ransackable_attributes(auth_object = nil)
    [ 'email', 'name', 'role' ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ 'resident', 'house' ]
  end
end
