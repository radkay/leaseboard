require "test_helper"

# Resident PII (name, phone, email) was showing in plain text in Render's logs
# on sign_new_lease (Ron, from production). These keys must stay filtered.
class FilterParametersTest < ActiveSupport::TestCase
  test "sign_new_lease resident PII is filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    # The shape the controller receives from units/_new_lease_form.html.erb.
    filtered = filter.filter(
      "resident" => {
        "first_name" => "Evan", "last_name" => "Field",
        "email" => "evan.field@example.test", "phone" => "555-0150"
      },
      "start_date" => "2026-01-01", "monthly_rent" => "1500"
    )

    resident = filtered["resident"]
    assert_equal "[FILTERED]", resident["first_name"]
    assert_equal "[FILTERED]", resident["last_name"]
    assert_equal "[FILTERED]", resident["email"]
    assert_equal "[FILTERED]", resident["phone"]

    # Non-PII fields are still logged, so logs stay useful.
    assert_equal "2026-01-01", filtered["start_date"]
    assert_equal "1500", filtered["monthly_rent"]
  end
end
