defmodule Board.Test.BoardReader do
  @moduledoc """
  Provisions the read-only `board_reader` role in the **test** database.

  Rails owns the real role (a migration, with the password from the environment).
  `structure.sql` carries no roles, so — exactly as the Rails fitness test does
  (`apps/admin/test/models/board_reader_test.rb`) — the board's own read-only test
  provisions an equivalent role with a throwaway test password: `SELECT` on the
  board-read views plus `properties`, and nothing else. This is test
  infrastructure, not a schema change; the role lives only in the ephemeral test
  database.
  """

  @name "board_reader"
  @password "board_reader_board_test_pw"

  # The board's read surface (CONTRACT.md §2–§5 plus `properties` for names),
  # matching Rails's BoardReaderRole::READABLE_RELATIONS.
  @readable ~w[
    unit_status_today
    property_kpis_today
    property_unit_type_kpis_today
    lease_expirations_12m
    properties
  ]

  def name, do: @name
  def password, do: @password

  @doc """
  Ensures the role exists with the test password and exactly the board's read
  grants. Run on an auto-committing connection (not the sandbox), so a second
  connection can authenticate as the role.
  """
  def provision!(conn, database) do
    # Fixed test literals with no quotes, so interpolation is safe here.
    Postgrex.query!(
      conn,
      """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{@name}') THEN
          ALTER ROLE #{@name} WITH LOGIN PASSWORD '#{@password}';
        ELSE
          CREATE ROLE #{@name} WITH LOGIN PASSWORD '#{@password}';
        END IF;
      END
      $$;
      """,
      []
    )

    # Start from nothing, then grant exactly what the board reads.
    Postgrex.query!(conn, "REVOKE ALL ON SCHEMA public FROM #{@name}", [])
    Postgrex.query!(conn, ~s(GRANT CONNECT ON DATABASE "#{database}" TO #{@name}), [])
    Postgrex.query!(conn, "GRANT USAGE ON SCHEMA public TO #{@name}", [])

    for relation <- @readable do
      Postgrex.query!(conn, "GRANT SELECT ON #{relation} TO #{@name}", [])
    end

    :ok
  end
end
