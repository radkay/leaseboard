require "test_helper"

class SeedTest < ActiveSupport::TestCase
  test "db:seed loads deterministic data: 3 properties, ~150 units, ~90% occupied" do
    Rails.application.load_seed

    assert_equal 3, Property.count
    assert_equal 150, Unit.count

    occupied_like = ActiveRecord::Base.connection.select_value(
      "SELECT count(*) FROM unit_status_today WHERE status IN ('occupied', 'on_notice', 'on_notice_rented')"
    )
    occupancy_pct = 100.0 * occupied_like / Unit.count
    assert_in_delta 90.0, occupancy_pct, 2.0

    # Every status appears (mix, not all-occupied).
    statuses = ActiveRecord::Base.connection
      .select_values("SELECT DISTINCT status FROM unit_status_today")
    assert_equal %w[occupied on_notice on_notice_rented vacant_available vacant_rented].sort, statuses.sort
  end

  test "seed residents are clearly synthetic" do
    Rails.application.load_seed

    assert_operator Resident.count, :>, 0
    assert Resident.all.all? { |r| r.email.end_with?("@example.com") }, "emails use the example.com reserved domain"
    assert Resident.all.all? { |r| r.phone.start_with?("(555) ") }, "phones use the 555 fake prefix"
  end
end
