class Unit < ApplicationRecord
  belongs_to :property, counter_cache: true
  has_many :leases, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :property_id }
  validates :bedrooms, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bathrooms, presence: true, numericality: { greater_than: 0 }
  validates :sq_ft, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :market_rent, presence: true, numericality: { greater_than: 0 }

  # 0 bedrooms is a studio (SPEC §5).
  def studio?
    bedrooms.zero?
  end
end
