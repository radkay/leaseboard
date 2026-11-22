require "test_helper"

class UnitsControllerTest < ActionDispatch::IntegrationTest
  setup { @unit = units(:sunset_101) }

  test "index, show, new and edit render" do
    get units_url
    assert_response :success
    get unit_url(@unit)
    assert_response :success
    get new_unit_url
    assert_response :success
    get edit_unit_url(@unit)
    assert_response :success
  end

  test "creates a unit" do
    assert_difference("Unit.count") do
      post units_url, params: {
        unit: { property_id: properties(:sunset).id, number: "909", bedrooms: 2,
                bathrooms: 2, sq_ft: 900, market_rent: 1600 }
      }
    end
    assert_redirected_to unit_url(Unit.last)
  end

  test "updates a unit" do
    patch unit_url(@unit), params: { unit: { market_rent: 1234 } }
    assert_redirected_to unit_url(@unit)
    assert_equal 1234, @unit.reload.market_rent
  end

  test "destroys a unit" do
    assert_difference("Unit.count", -1) { delete unit_url(@unit) }
    assert_redirected_to units_url
  end

  test "index relation is strict_loading, so an un-preloaded association raises (N+1 guard)" do
    unit = Unit.includes(:property).strict_loading.first
    assert_nothing_raised { unit.property.name } # preloaded
    assert_raises(ActiveRecord::StrictLoadingViolationError) { unit.leases.to_a }
  end

  test "sign_new_lease member action creates a resident and a lease" do
    unit = units(:sunset_102) # vacant
    assert_difference([ "Resident.count", "Lease.count" ], 1) do
      post sign_new_lease_unit_url(unit), params: {
        resident: { first_name: "Evan", last_name: "Field", email: "evan.field@example.test", phone: "555-0150" },
        start_date: Date.current.to_s, end_date: (Date.current + 365).to_s, monthly_rent: 1500
      }
    end
    assert_response :redirect
  end
end
