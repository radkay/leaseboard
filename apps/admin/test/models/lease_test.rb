require "test_helper"

class LeaseTest < ActiveSupport::TestCase
  test "valid fixture is valid" do
    assert leases(:sunset_101_active).valid?
  end

  test "requires unit, resident, dates, rent and status" do
    lease = Lease.new
    assert_not lease.valid?
    assert lease.errors.key?(:unit)
    assert lease.errors.key?(:resident)
    assert lease.errors.key?(:start_date)
    assert lease.errors.key?(:end_date)
    assert lease.errors.key?(:monthly_rent)
  end

  test "status is restricted to the four known values" do
    assert_equal %w[pending active notice_given ended], Lease.statuses.keys
    assert_raises(ArgumentError) { Lease.new(status: "squatting") }
  end

  test "end_date must be after start_date" do
    lease = build_lease(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 1))
    assert_not lease.valid?
    assert lease.errors.key?(:end_date)
  end

  test "monthly_rent must be positive" do
    lease = build_lease(monthly_rent: 0)
    assert_not lease.valid?
    assert lease.errors.key?(:monthly_rent)
  end

  test "rejects a live lease overlapping another live lease on the same unit" do
    active = leases(:sunset_101_active) # active, 2026-01-01..2026-12-31
    overlap = build_lease(unit: active.unit, start_date: Date.new(2026, 6, 1),
                          end_date: Date.new(2027, 5, 31), status: :active)
    assert_not overlap.valid?
    assert_includes overlap.errors[:base], "overlaps another live lease on this unit"
  end

  test "allows a pending lease that starts after the current lease ends" do
    active = leases(:sunset_101_active) # ends 2026-12-31
    nxt = build_lease(unit: active.unit, start_date: Date.new(2027, 1, 1),
                      end_date: Date.new(2027, 12, 31), status: :pending)
    assert nxt.valid?, nxt.errors.full_messages.to_sentence
  end

  test "an ended lease is ignored by the overlap rule" do
    active = leases(:sunset_101_active)
    ended = build_lease(unit: active.unit, start_date: active.start_date,
                        end_date: active.end_date, status: :ended)
    assert ended.valid?
    assert ended.save
  end

  test "database EXCLUDE constraint rejects overlapping live leases" do
    active = leases(:sunset_101_active)
    sql = Lease.sanitize_sql([
      "INSERT INTO leases (unit_id, resident_id, start_date, end_date, monthly_rent, status, created_at, updated_at) " \
      "VALUES (?, ?, DATE '2026-06-01', DATE '2027-05-31', 1000, 'active', now(), now())",
      active.unit_id, residents(:bob).id
    ])
    assert_raises(ActiveRecord::StatementInvalid) { Lease.connection.execute(sql) }
  end

  private

  def build_lease(**attrs)
    defaults = {
      unit: units(:sunset_102), resident: residents(:bob),
      start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31),
      monthly_rent: 1500, status: :active
    }
    Lease.new(**defaults.merge(attrs))
  end
end
