require "test_helper"
require "pg"

# Fitness test for the environment's read-only reader role (reader_test). The role
# and its grants are provisioned outside Rails: db/bootstrap creates the role, and
# db/privileges.sql (applied after the schema loads) grants it exactly the contract
# read surface. This test connects *as* reader_test and proves the boundary holds —
# it reads the contract objects, cannot write, cannot reach anything outside its
# grants, and cannot connect to another environment's database.
#
# CI (and db/bootstrap locally) provisions leaseboard_dev as well, so the cross-
# environment check is a real permission denial rather than a missing database.
class ReaderRoleTest < ActiveSupport::TestCase
  READER = "reader_test".freeze
  OTHER_ENV_DATABASE = "leaseboard_dev".freeze

  CONTRACT_RELATIONS = %w[
    unit_status_today
    property_kpis_today
    property_unit_type_kpis_today
    lease_expirations_12m
    properties
  ].freeze

  setup do
    @reader_password = ENV.fetch("READER_TEST_PASSWORD") do
      skip "READER_TEST_PASSWORD not set — run db/bootstrap test first (see db/bootstrap)."
    end
    @config = ActiveRecord::Base.connection_db_config.configuration_hash
  end

  test "reads every contract relation and the status function" do
    with_reader do |conn|
      CONTRACT_RELATIONS.each do |relation|
        assert_nothing_raised { conn.exec("SELECT * FROM #{relation} LIMIT 1") }
      end

      # The reader may call the SECURITY DEFINER function (the views do), and it
      # returns a lease id and no resident data.
      columns = conn.exec("SELECT * FROM unit_status_as_of(CURRENT_DATE) LIMIT 0").fields
      assert_includes columns, "current_lease_id"
      assert_empty columns.grep(/resident/i), "the function must not expose resident data"
    end
  end

  test "cannot write any table" do
    with_reader do |conn|
      assert_raises(PG::InsufficientPrivilege) do
        conn.exec(
          "INSERT INTO properties (name, address, city, state, units_count, created_at, updated_at) " \
          "VALUES ('x', 'y', 'z', 'TX', 0, now(), now())"
        )
      end
    end
  end

  test "cannot read anything outside its grants" do
    with_reader do |conn|
      # Base tables are never granted — no resident PII, no lease or unit rows.
      assert_raises(PG::InsufficientPrivilege) { conn.exec("SELECT * FROM residents") }
      assert_raises(PG::InsufficientPrivilege) { conn.exec("SELECT * FROM leases") }
      assert_raises(PG::InsufficientPrivilege) { conn.exec("SELECT * FROM units") }
    end
  end

  test "PUBLIC cannot execute the status function" do
    refute ActiveRecord::Base.connection.select_value(
      "SELECT has_function_privilege('public', 'unit_status_as_of(date)', 'EXECUTE')"
    ), "unit_status_as_of must be locked down: PUBLIC must not have EXECUTE"
  end

  test "cannot connect to another environment's database" do
    error = assert_raises(PG::ConnectionBad) do
      PG.connect(**reader_params(dbname: OTHER_ENV_DATABASE)).close
    end
    assert_match(/permission denied for database "?#{OTHER_ENV_DATABASE}"?/, error.message)
  end

  private

  def with_reader
    conn = PG.connect(**reader_params(dbname: @config[:database]))
    yield conn
  ensure
    conn&.close
  end

  def reader_params(dbname:)
    {
      host: @config[:host] || "localhost",
      port: @config[:port] || 5432,
      dbname: dbname,
      user: READER,
      password: @reader_password
    }
  end
end
