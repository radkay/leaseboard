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

  test "show lists the unit's leases, each linking to the lease" do
    get unit_url(@unit) # sunset_101, with one active lease (Alice)
    assert_response :success
    lease = leases(:sunset_101_active)
    assert_select "td a[href=?]", lease_path(lease), text: "Active"
    assert_select "td a[href=?]", lease_path(lease), text: "Alice Tenant"
  end

  test "unit show preloads the leases' residents (N+1 guard)" do
    rel = Lease.where(unit: units(:sunset_101)).includes(:resident).strict_loading
    rel.each { |lease| assert_nothing_raised { lease.resident.full_name } } # preloaded
    assert_raises(ActiveRecord::StrictLoadingViolationError) { rel.first.unit.number } # not preloaded
  end

  test "index relation is strict_loading, so an un-preloaded association raises (N+1 guard)" do
    unit = Unit.includes(:property).strict_loading.first
    assert_nothing_raised { unit.property.name } # preloaded
    assert_raises(ActiveRecord::StrictLoadingViolationError) { unit.leases.to_a }
  end

  test "the new-lease form renders the field names the controller expects" do
    # Guards against a mismatch between the form's field names and the strong
    # params the action requires: the controller tests below post a hand-built
    # hash, so only this test exercises the names the form actually renders.
    get unit_url(@unit)
    assert_response :success
    %w[resident[first_name] resident[last_name] resident[email] resident[phone]].each do |name|
      assert_select "form input[name=?]", name
    end
    %w[start_date end_date monthly_rent].each do |name|
      assert_select "form input[name=?]", name
    end
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

  test "sign_new_lease via turbo_stream adds the lease row and resets the form (success)" do
    unit = units(:sunset_102) # vacant
    assert_difference([ "Resident.count", "Lease.count" ], 1) do
      post sign_new_lease_unit_url(unit), as: :turbo_stream, params: {
        resident: { first_name: "Evan", last_name: "Field", email: "evan.field@example.test", phone: "555-0150" },
        start_date: Date.current.to_s, end_date: (Date.current + 365).to_s, monthly_rent: 1500
      }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_select "turbo-stream[action=prepend][target=unit_leases]"
    assert_select "turbo-stream[action=replace][target=new_lease_form]"
    assert_match "Evan Field", @response.body
  end

  test "sign_new_lease via turbo_stream re-renders the form with errors (validation error)" do
    unit = units(:sunset_101) # already has an active lease, so a new one overlaps
    assert_no_difference([ "Resident.count", "Lease.count" ]) do
      post sign_new_lease_unit_url(unit), as: :turbo_stream, params: {
        resident: { first_name: "Olive", last_name: "Lap", email: "olive.lap@example.test", phone: "555-0160" },
        start_date: "2026-06-01", end_date: "2027-05-31", monthly_rent: 1500
      }
    end
    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new_lease_form]"
    assert_match "overlaps another live lease on this unit", @response.body
  end
end
