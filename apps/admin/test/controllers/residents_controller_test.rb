require "test_helper"

class ResidentsControllerTest < ActionDispatch::IntegrationTest
  setup { @resident = residents(:alice) }

  test "show, new and edit render" do
    get resident_url(@resident)
    assert_response :success
    get new_resident_url
    assert_response :success
    get edit_resident_url(@resident)
    assert_response :success
  end

  test "creates a resident" do
    assert_difference("Resident.count") do
      post residents_url, params: {
        resident: { first_name: "Carol", last_name: "New", email: "carol.new@example.test", phone: "555-0199" }
      }
    end
    assert_redirected_to resident_url(Resident.last)
  end

  test "updates a resident" do
    patch resident_url(@resident), params: { resident: { phone: "555-7777" } }
    assert_redirected_to resident_url(@resident)
    assert_equal "555-7777", @resident.reload.phone
  end
end
