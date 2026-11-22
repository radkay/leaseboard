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
