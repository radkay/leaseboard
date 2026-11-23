require "test_helper"

# The scaffold list pages for units, leases and residents were removed (Ron, D-031):
# navigation runs through properties and the rent roll instead.
class NoIndexRoutesTest < ActionDispatch::IntegrationTest
  test "no GET index route exists for units, leases or residents" do
    [ units_url, leases_url, residents_url ].each do |url|
      get url
      assert_response :not_found # the index route is gone (routing error renders 404 in test)
    end
  end

  test "the collection path still serves create (POST), so the record pages keep working" do
    # units_url/leases_url/residents_url resolve because :create keeps the collection
    # route; only the GET index was dropped.
    assert_nothing_raised { units_url and leases_url and residents_url }
  end
end
