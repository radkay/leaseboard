require "test_helper"

class ResidentsControllerTest < ActionDispatch::IntegrationTest
  setup { @resident = residents(:alice) }

  test "index, show, new and edit render" do
    get residents_url
    assert_response :success
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

  test "destroys a resident (dependent leases cascade)" do
    assert_difference("Resident.count", -1) { delete resident_url(residents(:bob)) }
    assert_redirected_to residents_url
  end
end
