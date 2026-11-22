require "test_helper"

# Destroy was removed everywhere (Ron, #80): records are never deleted through the UI.
class NoDestroyRoutesTest < ActionDispatch::IntegrationTest
  test "no DELETE route exists for properties, units, leases or residents" do
    [ property_url(properties(:sunset)), unit_url(units(:sunset_101)),
      lease_url(leases(:sunset_101_active)), resident_url(residents(:alice)) ].each do |url|
      delete url
      assert_response :not_found # the DELETE route is gone (routing error renders 404 in test)
    end
  end
end
