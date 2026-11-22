require "test_helper"

# Exercises the four board-read views (CONTRACT.md §2–§5). Data is built relative to
# Date.current so the "today" views derive the intended status for each unit.
class StatusViewsTest < ActiveSupport::TestCase
  setup do
    @today = Date.current
    @property = Property.create!(name: "Test Towers", address: "1 Test St", city: "Austin", state: "TX")
    @resident = Resident.create!(first_name: "Test", last_name: "Resident",
                                 email: "views-res@example.test", phone: "555-0000")

    @occupied         = create_unit("101", 1)
    @on_notice        = create_unit("102", 1)
    @on_notice_rented = create_unit("201", 2)
    @vacant_rented    = create_unit("202", 2)
    @vacant_available = create_unit("301", 0)

    lease(@occupied, @today - 100, @today + 300, :active)
    lease(@on_notice, @today - 100, @today + 300, :notice_given,
          notice_date: @today - 10, move_out_date: @today + 300)
    lease(@on_notice_rented, @today - 100, @today + 300, :notice_given,
          notice_date: @today - 5, move_out_date: @today + 300)
    lease(@on_notice_rented, @today + 301, @today + 665, :pending)
    lease(@vacant_rented, @today + 10, @today + 375, :pending)
    # @vacant_available: no leases.
  end

  test "unit_status_today derives every status rule" do
    assert_equal "occupied", status_of(@occupied)
    assert_equal "on_notice", status_of(@on_notice)
    assert_equal "on_notice_rented", status_of(@on_notice_rented)
    assert_equal "vacant_rented", status_of(@vacant_rented)
    assert_equal "vacant_available", status_of(@vacant_available)
  end

  test "unit_status_today carries unit-type and current/next-lease fields" do
    occ = ust_row(@occupied)
    assert_equal 1, occ["bedrooms"]
    assert_equal 1500.0, occ["current_monthly_rent"].to_f
    assert_equal(@today + 300, occ["current_lease_end_date"])
    assert_nil occ["next_lease_start_date"]

    onr = ust_row(@on_notice_rented)
    assert_equal(@today + 301, onr["next_lease_start_date"])
    assert_equal(@today - 5, onr["notice_date"])

    vacant = ust_row(@vacant_available)
    assert_nil vacant["current_monthly_rent"]
    assert_nil vacant["current_lease_end_date"]
    assert_nil vacant["next_lease_start_date"]
  end

  test "property_kpis_today computes the D-010 KPIs over the property" do
    k = kpis(@property)
    assert_equal 5, k["total_units"]
    assert_equal 1, k["occupied"]
    assert_equal 1, k["on_notice"]
    assert_equal 1, k["on_notice_rented"]
    assert_equal 1, k["vacant_rented"]
    assert_equal 1, k["vacant_available"]
    # occupancy = (occupied + on_notice + on_notice_rented) / 5
    assert_equal 60.0, k["occupancy_pct"].to_f
    # leased = (occupied + on_notice_rented + vacant_rented) / 5
    assert_equal 60.0, k["leased_pct"].to_f
    # available = vacant_available + on_notice
    assert_equal 2, k["available_units"]
  end

  test "property_unit_type_kpis_today breaks the KPIs out by bedroom count" do
    studio = type_kpis(@property, 0)
    assert_equal 1, studio["total_units"]
    assert_equal 0.0, studio["occupancy_pct"].to_f
    assert_equal 0.0, studio["leased_pct"].to_f
    assert_equal 1, studio["available_units"]

    one_bed = type_kpis(@property, 1) # occupied + on_notice
    assert_equal 2, one_bed["total_units"]
    assert_equal 100.0, one_bed["occupancy_pct"].to_f
    assert_equal 50.0, one_bed["leased_pct"].to_f
    assert_equal 1, one_bed["available_units"]

    two_bed = type_kpis(@property, 2) # on_notice_rented + vacant_rented
    assert_equal 2, two_bed["total_units"]
    assert_equal 50.0, two_bed["occupancy_pct"].to_f
    assert_equal 100.0, two_bed["leased_pct"].to_f
    assert_equal 0, two_bed["available_units"]
  end

  test "a property with no units reports zeroes without dividing by zero" do
    empty = Property.create!(name: "Empty", address: "9 X St", city: "Austin", state: "TX")
    k = kpis(empty)
    assert_equal 0, k["total_units"]
    assert_equal 0.0, k["occupancy_pct"].to_f
    assert_equal 0.0, k["leased_pct"].to_f
    assert_equal 0, k["available_units"]
  end

  test "lease_expirations_12m splits renewed/relet vs open over a dense 12-month window" do
    prop = Property.create!(name: "Expiry", address: "2 Exp St", city: "Austin", state: "TX")
    eom = @today.end_of_month
    relet = prop.units.create!(number: "A", bedrooms: 1, bathrooms: 1, sq_ft: 600, market_rent: 1500)
    open  = prop.units.create!(number: "B", bedrooms: 1, bathrooms: 1, sq_ft: 600, market_rent: 1500)

    relet.leases.create!(resident: @resident, start_date: @today - 300, end_date: eom,
                         monthly_rent: 1500, status: :active)
    relet.leases.create!(resident: @resident, start_date: eom + 1, end_date: eom + 365,
                         monthly_rent: 1600, status: :pending) # follow-on
    open.leases.create!(resident: @resident, start_date: @today - 300, end_date: eom,
                        monthly_rent: 1500, status: :active) # no follow-on

    rows = expirations(prop)
    assert_equal 12, rows.length, "dense 12-month window per property"
    assert_equal @today.beginning_of_month, rows.first["month"]

    current = rows.first
    assert_equal 2, current["expiring_total"]
    assert_equal 1, current["expiring_renewed_or_relet"]
    assert_equal 1, current["expiring_open"]

    rows.each do |r|
      assert_equal r["expiring_total"], r["expiring_renewed_or_relet"] + r["expiring_open"],
        "total must equal renewed/relet + open for #{r['month']}"
    end
  end

  private

  def conn
    ActiveRecord::Base.connection
  end

  def create_unit(number, bedrooms)
    @property.units.create!(number: number, bedrooms: bedrooms, bathrooms: 1, sq_ft: 600, market_rent: 1500)
  end

  def lease(unit, start_date, end_date, status, **attrs)
    unit.leases.create!(resident: @resident, start_date: start_date, end_date: end_date,
                        monthly_rent: 1500, status: status, **attrs)
  end

  def status_of(unit)
    conn.select_value("SELECT status FROM unit_status_today WHERE unit_id = #{unit.id}")
  end

  def ust_row(unit)
    conn.select_one("SELECT * FROM unit_status_today WHERE unit_id = #{unit.id}")
  end

  def kpis(property)
    conn.select_one("SELECT * FROM property_kpis_today WHERE property_id = #{property.id}")
  end

  def type_kpis(property, bedrooms)
    conn.select_one(
      "SELECT * FROM property_unit_type_kpis_today WHERE property_id = #{property.id} AND bedrooms = #{bedrooms}"
    )
  end

  def expirations(property)
    conn.select_all("SELECT * FROM lease_expirations_12m WHERE property_id = #{property.id} ORDER BY month").to_a
  end
end
