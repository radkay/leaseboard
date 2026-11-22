require "test_helper"

class PropertiesControllerTest < ActionDispatch::IntegrationTest
  setup { @property = properties(:sunset) }

  test "index, show, new and edit render" do
    get properties_url
    assert_response :success
    get property_url(@property)
    assert_response :success
    get new_property_url
    assert_response :success
    get edit_property_url(@property)
    assert_response :success
  end

  test "creates a property" do
    assert_difference("Property.count") do
      post properties_url, params: {
        property: { name: "New Place", address: "5 New St", city: "Austin", state: "TX", sanity_slug: "new-place" }
      }
    end
    assert_redirected_to property_url(Property.last)
  end

  test "updates a property" do
    patch property_url(@property), params: { property: { name: "Renamed" } }
    assert_redirected_to property_url(@property)
    assert_equal "Renamed", @property.reload.name
  end

  test "destroys a property" do
    assert_difference("Property.count", -1) { delete property_url(@property) }
    assert_redirected_to properties_url
  end

  test "requires authentication" do
    bad = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong-password")
    get properties_url, headers: { "Authorization" => bad }
    assert_response :unauthorized
  end
end
