ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Rails' automatic test-schema maintenance is off (config/environments/test.rb): it
# purges the database, which the non-superuser owner can't do. Check the schema is
# current ourselves and fail fast with the in-place refresh command if it isn't.
unless ActiveRecord::Tasks::DatabaseTasks.schema_up_to_date?(ActiveRecord::Base.connection_db_config)
  abort <<~MSG
    [leaseboard] The test database schema is out of date (apps/admin/db/structure.sql changed).
    The test owner (admin_test) isn't a superuser and can't recreate the database, so refresh
    it in place:

        RAILS_ENV=test bin/rails db:test:refresh

    (First run `db/bootstrap test` if leaseboard_test or its roles don't exist yet.)
  MSG
end

module ActiveSupport
  class TestCase
    # Single test database (leaseboard_test), created once by db/bootstrap. The
    # reader fitness test connects as a second role and asserts cross-environment
    # isolation, so there is exactly one test database — no per-worker copies.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Temporarily set ENV vars for the duration of a block, restoring the originals after.
    # Used to drive Sanity's env-based configuration without touching global state.
    def with_env(vars)
      originals = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    # Swap Sanity's network boundary for a stub callable (see Sanity.transport), restoring
    # the real Net::HTTP transport after. Lets tests exercise the client with no network call
    # and no mocking gem.
    def with_sanity_transport(callable)
      Sanity.transport = callable
      yield
    ensure
      Sanity.transport = nil
    end
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
