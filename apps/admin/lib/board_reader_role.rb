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

    create_or_update_role!(connection, name: NAME, password: password)
    grant_reads!(connection)
  end

  # Race-safe create-or-update of a login role. A check-then-create (IF NOT EXISTS …
  # CREATE) races under parallel processes because roles are cluster-wide: two sessions
  # can both pass the existence check and CREATE, hitting a duplicate key on pg_authid.
  # Instead, attempt CREATE and fall back to ALTER on a duplicate, which is also safe if
  # two deploys run migrations at once (R-016). `name` is always a trusted constant.
  def create_or_update_role!(connection, name:, password:)
    quoted_password = connection.quote(password)
    connection.execute(<<~SQL)
      DO $$
      BEGIN
        CREATE ROLE #{name} WITH LOGIN PASSWORD #{quoted_password};
      EXCEPTION
        WHEN duplicate_object OR unique_violation THEN
          ALTER ROLE #{name} WITH LOGIN PASSWORD #{quoted_password};
      END
      $$;
    SQL
  end

  # (Re-)applies exactly the read grants board_reader needs. Idempotent, and must be
  # re-run after any of the views is dropped and recreated (dropping a view drops its
  # grants), which is why the status-view migrations call it.
  def grant_reads!(connection)
    return unless connection.select_value("SELECT 1 FROM pg_roles WHERE rolname = '#{NAME}'")

    database = %("#{connection.current_database}")
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
