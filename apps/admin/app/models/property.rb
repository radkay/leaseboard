class Property < ApplicationRecord
  has_many :units, dependent: :destroy

  validates :name, :address, :city, :state, presence: true
  validates :sanity_slug, uniqueness: true, allow_nil: true
end
