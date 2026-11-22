defmodule Board.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Board.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Board.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Board.DataCase
    end
  end

  setup tags do
    Board.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Board.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Runs `fun` with the connection switched to the read-only `reader_test` role for
  the rest of the current (sandboxed) transaction, then resets it.

  The test harness connects and inserts fixtures as the owner `admin_test`; the
  board's real query functions are run inside `as_reader/1` so they execute with
  only the reader's grants (SELECT on the views, EXECUTE on the status function —
  no base tables, no writes). That is the board's read-only guarantee, exercised
  against the actual role rather than a stand-in.

  `SET LOCAL ROLE` is scoped to the surrounding transaction (the sandbox's), so it
  cannot leak across the pooled connection; `RESET ROLE` restores the owner for any
  later fixture work in the same test. `admin_test` is granted membership in
  `reader_test` in the test environment only, which is what lets it switch.
  See the Postgres manual: https://www.postgresql.org/docs/current/sql-set-role.html
  """
  def as_reader(fun) when is_function(fun, 0) do
    Board.Repo.query!("SET LOCAL ROLE reader_test")

    try do
      fun.()
    after
      Board.Repo.query!("RESET ROLE")
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
