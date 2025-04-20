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
end
