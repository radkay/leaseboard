require "test_helper"

class LeasesControllerTest < ActionDispatch::IntegrationTest
  setup { @lease = leases(:sunset_101_active) }

  test "index, show, new and edit render" do
    get leases_url
    assert_response :success
    get lease_url(@lease)
    assert_response :success
    get new_lease_url
    assert_response :success
    get edit_lease_url(@lease)
    assert_response :success
  end

  test "creates a lease on a free unit" do
    assert_difference("Lease.count") do
      post leases_url, params: {
        lease: { unit_id: units(:sunset_102).id, resident_id: residents(:bob).id,
                 start_date: "2026-02-01", end_date: "2027-02-01", monthly_rent: 1700, status: "active" }
      }
    end
    assert_redirected_to lease_url(Lease.last)
  end

  test "rejects an overlapping lease with a validation error" do
    assert_no_difference("Lease.count") do
      post leases_url, params: {
        lease: { unit_id: units(:sunset_101).id, resident_id: residents(:bob).id,
                 start_date: "2026-06-01", end_date: "2027-05-31", monthly_rent: 1000, status: "active" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "updates a lease" do
    patch lease_url(@lease), params: { lease: { monthly_rent: 1001 } }
    assert_redirected_to lease_url(@lease)
    assert_equal 1001, @lease.reload.monthly_rent
  end

  test "destroys a lease" do
    assert_difference("Lease.count", -1) { delete lease_url(@lease) }
    assert_redirected_to leases_url
  end
end
