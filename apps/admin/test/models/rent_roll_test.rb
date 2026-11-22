require "test_helper"

class RentRollTest < ActiveSupport::TestCase
  test "totals match the seed data and the report is a single query" do
    Rails.application.load_seed
    property = Property.find_by!(name: "Maple Court")
    conn = ActiveRecord::Base.connection

    rent_roll = RentRoll.new(property, as_of: Date.current)

    # One row per unit.
    assert_equal property.units.count, rent_roll.total_units

    # Occupancy matches the board KPI view for the same property.
    kpi_occupancy = conn.select_value(
      "SELECT occupancy_pct FROM property_kpis_today WHERE property_id = #{property.id}"
    ).to_f
    assert_in_delta kpi_occupancy, rent_roll.occupancy_pct, 0.01

    # Scheduled rent is the sum of the live leases' rent, checked against the function.
    expected_rent = conn.select_value(
      "SELECT COALESCE(SUM(current_monthly_rent), 0) FROM unit_status_as_of(CURRENT_DATE) " \
      "WHERE property_id = #{property.id}"
    ).to_f
    assert_in_delta expected_rent, rent_roll.scheduled_rent.to_f, 0.01

    # No N+1: rows + every total + the CSV come from one query (uncached, so the query
    # actually runs rather than being served from the query cache).
    fresh = RentRoll.new(property)
    assert_queries_count(1) do
      ActiveRecord::Base.uncached do
        fresh.rows
        fresh.occupancy_pct
        fresh.scheduled_rent
        fresh.to_csv
      end
    end
  end
end
