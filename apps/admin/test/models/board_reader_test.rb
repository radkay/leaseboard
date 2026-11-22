require "test_helper"
require "pg"

class BoardReaderTest < ActiveSupport::TestCase
  # board_reader must be a committed, cluster-global role for a second connection to
  # authenticate as it, so this test provisions it directly rather than relying on the
  # per-test transaction (which would roll the role back before we could connect).
  self.use_transactional_tests = false

  TEST_PASSWORD = "board_reader_fitness_pw".freeze

  setup do
    BoardReaderRole.install!(ActiveRecord::Base.connection, password: TEST_PASSWORD)
  end

  test "board_reader can read a view but cannot write or read resident PII" do
    conn = board_reader_connection
    begin
      # Reading a board-read view is allowed (the view runs with its owner's rights on
      # the base tables; board_reader only needs SELECT on the view itself).
      assert_nothing_raised do
        conn.exec("SELECT count(*) FROM property_kpis_today")
      end

      # Writing any table is denied — the board is read-only (SPEC "one writer").
      assert_raises(PG::InsufficientPrivilege) do
        conn.exec(
          "INSERT INTO properties (name, address, city, state, units_count, created_at, updated_at) " \
          "VALUES ('x', 'y', 'z', 'TX', 0, now(), now())"
        )
      end

      # Resident PII is not granted, so it can't be read at all (CONTRACT.md scope note).
      assert_raises(PG::InsufficientPrivilege) do
        conn.exec("SELECT * FROM residents")
      end
    ensure
      conn.close
    end
  end

  test "the status function is locked to board_reader and exposes no resident data" do
    conn = ActiveRecord::Base.connection
    # Mirror the migration: structure.sql carries no function privileges, so apply them here.
    conn.execute("REVOKE EXECUTE ON FUNCTION unit_status_as_of(date) FROM PUBLIC")
    conn.execute("GRANT EXECUTE ON FUNCTION unit_status_as_of(date) TO board_reader")

    # No arbitrary role can call the SECURITY DEFINER function.
    refute conn.select_value("SELECT has_function_privilege('public', 'unit_status_as_of(date)', 'EXECUTE')")

    reader = board_reader_connection
    begin
      # board_reader reads every board view (which call the function with the owner's rights).
      %w[unit_status_today property_kpis_today property_unit_type_kpis_today lease_expirations_12m].each do |view|
        assert_nothing_raised { reader.exec("SELECT count(*) FROM #{view}") }
      end

      # board_reader may call the function, but it returns a lease id and no resident data.
      columns = reader.exec("SELECT * FROM unit_status_as_of(CURRENT_DATE) LIMIT 0").fields
      assert_includes columns, "current_lease_id"
      assert_empty columns.grep(/resident/i), "the function must not expose resident data"
    ensure
      reader.close
      conn.execute("GRANT EXECUTE ON FUNCTION unit_status_as_of(date) TO PUBLIC")
    end
  end

  private

  def board_reader_connection
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    PG.connect(
      host: cfg[:host] || "localhost",
      port: cfg[:port] || 5432,
      dbname: cfg[:database],
      user: BoardReaderRole::NAME,
      password: TEST_PASSWORD
    )
  end
end
