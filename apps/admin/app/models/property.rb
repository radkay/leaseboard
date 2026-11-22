class Property < ApplicationRecord
  has_many :units, dependent: :destroy

  validates :name, :address, :city, :state, presence: true
  validates :sanity_slug, uniqueness: true, allow_nil: true

  # Units available to rent right now, read live from the Rails-owned property_kpis_today
  # view (status rules live in one place — CLAUDE.md). Returns 0 when the property has no row.
  def available_units
    self.class.connection.select_value(
      self.class.sanitize_sql_array(
        [ "SELECT available_units FROM property_kpis_today WHERE property_id = ?", id ]
      )
    ).to_i
  end
end
