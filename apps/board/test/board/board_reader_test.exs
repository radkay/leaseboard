defmodule Board.BoardReaderTest do
  # No sandbox: the role must be committed for a second connection to
  # authenticate as it, mirroring apps/admin/test/models/board_reader_test.rb.
  use ExUnit.Case, async: false

  alias Board.LeaseChangeListener
  alias Board.Test.BoardReader

  setup do
    owner_opts = LeaseChangeListener.repo_connection_opts()
    {:ok, owner} = Postgrex.start_link(owner_opts)
    BoardReader.provision!(owner, Keyword.fetch!(owner_opts, :database))

    reader_opts =
      owner_opts
      |> Keyword.put(:username, BoardReader.name())
      |> Keyword.put(:password, BoardReader.password())

    {:ok, reader} = Postgrex.start_link(reader_opts)

    %{reader: reader}
  end

  test "board_reader may read a board view", %{reader: reader} do
    assert {:ok, _} = Postgrex.query(reader, "SELECT count(*) FROM property_kpis_today", [])
  end

  test "board_reader cannot write any table", %{reader: reader} do
    assert {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} =
             Postgrex.query(
               reader,
               """
               INSERT INTO properties (name, address, city, state, units_count, created_at, updated_at)
               VALUES ('x', 'y', 'z', 'TX', 0, now(), now())
               """,
               []
             )
  end

  test "board_reader cannot read resident PII", %{reader: reader} do
    assert {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} =
             Postgrex.query(reader, "SELECT * FROM residents", [])
  end
end
