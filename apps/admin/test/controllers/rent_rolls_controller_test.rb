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

  test "requires authentication" do
    bad = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "nope")
    get rent_roll_url, headers: { "Authorization" => bad }
    assert_response :unauthorized
  end
end
