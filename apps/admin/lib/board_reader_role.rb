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

  # Create-or-update a login role, race-safe when the cluster-wide role is set up from
  # many databases at once (Rails runs each parallel test worker in its own database, so a
  # per-database advisory lock can't serialise them — R-016). The DO block swallows a
  # duplicate from a concurrent CREATE; the retry handles "tuple concurrently updated" from
  # concurrent ALTERs on the shared pg_authid row. `name` is always a trusted constant.
  def create_or_update_role!(connection, name:, password:)
    quoted_password = connection.quote(password)
    with_retry_on_role_contention do
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
  end

  # (Re-)applies exactly the read grants board_reader needs. Idempotent, and must be
  # re-run after any of the views is dropped and recreated (dropping a view drops its
  # grants), which is why the status-view migrations call it. These objects are all
  # per-database, so parallel workers grant on their own copies and don't contend.
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

  # Retries a few times on the transient errors Postgres raises when the same cluster-wide
  # role is created/altered from concurrent sessions. Safe only outside an open
  # transaction (migrations are already serialised by Rails' own migration lock).
  def with_retry_on_role_contention
    attempts = 0
    begin
      yield
    rescue ActiveRecord::StatementInvalid => e
      attempts += 1
      raise if attempts > 5 || !role_contention?(e)

      sleep(0.02 * attempts)
      retry
    end
  end

  def role_contention?(error)
    message = error.message
    message.include?("tuple concurrently updated") || message.include?("duplicate key value")
  end
end
