# Installs the read-only board_reader role used by the Phoenix board. Shared by the
# migration (dev/production, password from the environment) and the fitness test (CI,
# where structure.sql carries no roles, so the test provisions it with a test password).
#
# board_reader may SELECT the four board-read views and the properties table (for names)
# and nothing else — no residents, so no PII, and no write privileges anywhere.
module BoardReaderRole
  NAME = "board_reader".freeze

  READABLE_RELATIONS = %w[
    unit_status_today
    property_kpis_today
    property_unit_type_kpis_today
    lease_expirations_12m
    properties
  ].freeze

  module_function

  def install!(connection, password:)
    raise ArgumentError, "board_reader password is required" if password.to_s.empty?

    quoted_password = connection.quote(password)
    database = %("#{connection.current_database}")

    connection.execute(<<~SQL)
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{NAME}') THEN
          ALTER ROLE #{NAME} WITH LOGIN PASSWORD #{quoted_password};
        ELSE
          CREATE ROLE #{NAME} WITH LOGIN PASSWORD #{quoted_password};
        END IF;
      END
      $$;
    SQL

    # Start from nothing, then grant exactly what the board reads.
    connection.execute("REVOKE ALL ON SCHEMA public FROM #{NAME}")
    connection.execute("GRANT CONNECT ON DATABASE #{database} TO #{NAME}")
    connection.execute("GRANT USAGE ON SCHEMA public TO #{NAME}")
    READABLE_RELATIONS.each do |relation|
      connection.execute("GRANT SELECT ON #{connection.quote_table_name(relation)} TO #{NAME}")
    end
  end

  # Revokes the current database's grants. The role is a cluster-global object that may
  # be granted in other databases, so it is not dropped here.
  def revoke!(connection)
    return unless connection.select_value("SELECT 1 FROM pg_roles WHERE rolname = '#{NAME}'")

    connection.execute("REVOKE ALL ON ALL TABLES IN SCHEMA public FROM #{NAME}")
    connection.execute("REVOKE ALL ON SCHEMA public FROM #{NAME}")
  end
end
