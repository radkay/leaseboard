ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# The whole admin is behind HTTP basic auth. Inject the credentials into every
# integration request by default; the "requires authentication" tests use a fresh
# open_session to make an un-authenticated request.
class ActionDispatch::IntegrationTest
  ADMIN_AUTH = ActionController::HttpAuthentication::Basic.encode_credentials(
    ENV["ADMIN_USERNAME"] || "admin",
    ENV["ADMIN_PASSWORD"] || "change-me"
  )

  %i[get post patch put delete].each do |verb|
    define_method(verb) do |path, **kwargs|
      kwargs[:headers] = { "Authorization" => ADMIN_AUTH }.merge(kwargs[:headers] || {})
      super(path, **kwargs)
    end
  end
end
