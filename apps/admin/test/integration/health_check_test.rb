require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  # Render (and any uptime monitor) polls /up without credentials, so it must sit outside
  # the admin's basic auth. Prove that by sending a wrong Authorization header and still
  # getting 200 — the health controller doesn't inherit ApplicationController's auth.
  test "/up is public and returns 200" do
    wrong = ActionController::HttpAuthentication::Basic.encode_credentials("nobody", "nope")
    get "/up", headers: { "Authorization" => wrong }
    assert_response :success
  end
end
