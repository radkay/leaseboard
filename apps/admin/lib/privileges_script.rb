# Applies db/privileges.sql — the single source of the reader role's grants and the
# status-function lockdown (CONTRACT.md). Shared by the db:privileges rake task,
# which runs after every database build (see lib/tasks/privileges.rake).
#
# The SQL file is parameterised with psql-style :db / :owner / :reader identifiers so
# it also runs under psql. Here we bind them from the connection's own config and the
# `reader_role` key in config/database.yml, then execute through ActiveRecord so the
# deploy needs no psql client.
module PrivilegesScript
  PATH = Rails.root.join("db", "privileges.sql")
  # Postgres unquoted identifier; the role/database names in the contract all match.
  IDENTIFIER = /\A[a-z_][a-z0-9_]*\z/

  module_function

  def apply!(connection = ActiveRecord::Base.connection)
    names = names_for(connection)
    ensure_reader_exists!(connection, names[:reader])
    connection.execute(render(names, connection))
  end

  def names_for(connection)
    config = connection.pool.db_config.configuration_hash
    {
      db: connection.current_database,
      owner: config.fetch(:username),
      reader: config.fetch(:reader_role) do
        raise KeyError, "config/database.yml is missing `reader_role` for #{Rails.env}"
      end
    }
  end

  # Substitute the :db/:owner/:reader placeholders with validated, quoted identifiers.
  def render(names, connection)
    names.each_value { |name| validate!(name) }
    File.read(PATH).gsub(/:(db|owner|reader)\b/) do
      connection.quote_column_name(names.fetch(Regexp.last_match(1).to_sym))
    end
  end

  def validate!(name)
    return if name.to_s.match?(IDENTIFIER)

    raise ArgumentError, "unsafe SQL identifier: #{name.inspect}"
  end

  # The bootstrap script (db/bootstrap) creates the reader role before the database
  # is built; fail with a clear message if that step was skipped.
  def ensure_reader_exists!(connection, reader)
    validate!(reader)
    return if connection.select_value(
      "SELECT 1 FROM pg_roles WHERE rolname = #{connection.quote(reader)}"
    )

    raise "reader role #{reader.inspect} does not exist — run db/bootstrap first"
  end
end
