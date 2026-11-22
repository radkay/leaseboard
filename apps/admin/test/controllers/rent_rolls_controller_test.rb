require "test_helper"

class RentRollsControllerTest < ActionDispatch::IntegrationTest
  test "renders the rent roll for a property as of a date" do
    get rent_roll_url(property_id: properties(:sunset).id, as_of: Date.current.to_s)
    assert_response :success
    assert_select "h1", "Rent roll"
  end

  test "exports the rent roll as CSV" do
    get rent_roll_url(property_id: properties(:sunset).id, format: :csv)
    assert_response :success
    assert_equal "text/csv", @response.media_type
    assert_includes @response.body, "Unit,Bedrooms,Status,Resident,Monthly rent,Market rent,Lease end"
  end

  test "links the unit to its page, and a leased unit's resident to its lease" do
    get rent_roll_url(property_id: properties(:sunset).id, as_of: Date.current.to_s)
    assert_response :success
    leased = units(:sunset_101) # occupied by Alice
    vacant = units(:sunset_102) # no current lease
    lease = leases(:sunset_101_active)
    # the unit number links to the unit, for both leased and vacant units
    assert_select "td a[href=?]", unit_path(leased), text: leased.number
    assert_select "td a[href=?]", unit_path(vacant), text: vacant.number
    # the leased unit's resident links to its lease; the vacant unit has no resident link
    assert_select "td a[href=?]", lease_path(lease), text: "Alice Tenant"
    assert_select "td", text: "—"
  end

  test "requires authentication" do
    bad = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "nope")
    get rent_roll_url, headers: { "Authorization" => bad }
    assert_response :unauthorized
  end
end
