require "test_helper"

class LeasesActionsTest < ActiveSupport::TestCase
  test "GiveNotice moves an active lease to notice_given with the dates" do
    lease = leases(:sunset_101_active)
    move_out = Date.current + 45

    Leases::GiveNotice.call(lease, move_out_date: move_out)

    lease.reload
    assert lease.notice_given?
    assert_equal Date.current, lease.notice_date
    assert_equal move_out, lease.move_out_date
  end

  test "SignRenewal creates a pending follow-on term starting after the current lease" do
    lease = leases(:sunset_101_active) # active, ends 2026-12-31
    new_end = lease.end_date + 365

    assert_difference("Lease.count", 1) do
      renewal = Leases::SignRenewal.call(lease, new_end_date: new_end, monthly_rent: 1234)
      assert renewal.pending?
      assert_equal lease.unit_id, renewal.unit_id
      assert_equal lease.resident_id, renewal.resident_id
      assert_equal lease.end_date + 1, renewal.start_date
      assert_equal new_end, renewal.end_date
    end
  end

  test "SignNewLease creates the resident and the lease together" do
    unit = units(:sunset_102) # vacant (only an ended lease)

    assert_difference([ "Resident.count", "Lease.count" ], 1) do
      lease = Leases::SignNewLease.call(
        unit: unit,
        resident_attributes: { first_name: "Dana", last_name: "New", email: "dana.new@example.test", phone: "555-0123" },
        start_date: Date.current, end_date: Date.current + 365, monthly_rent: 1500
      )
      assert lease.active?
      assert_equal "Dana", lease.resident.first_name
    end
  end

  test "SignNewLease rolls back the resident when the lease is invalid" do
    unit = units(:sunset_101) # already has an active lease covering today

    assert_no_difference([ "Resident.count", "Lease.count" ]) do
      assert_raises(ActiveRecord::RecordInvalid) do
        Leases::SignNewLease.call(
          unit: unit,
          resident_attributes: { first_name: "Temp", last_name: "Fail", email: "temp.fail@example.test", phone: "555-9999" },
          start_date: Date.current, end_date: Date.current + 200, monthly_rent: 1000
        )
      end
    end
  end
end
