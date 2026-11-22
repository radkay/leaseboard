defmodule Board.ReadOnlyTest do
  # The board's read-only guarantee, exercised against the real `reader_test` role.
  # The owner `admin_test` inserts fixtures, then — in the same sandbox transaction
  # — `SET LOCAL ROLE reader_test` switches to the role the board's queries run as
  # and proves it can read the views but cannot write or read resident PII.
  #
  # Postgres SET ROLE: https://www.postgresql.org/docs/current/sql-set-role.html
  use Board.DataCase, async: true

  alias Board.Occupancy
  alias Board.Test.Seeds

  setup do
    property_id = Seeds.insert_property(name: "Maple Court")
    resident_id = Seeds.insert_resident()
    unit_id = Seeds.insert_unit(property_id, number: "101")
    Seeds.insert_lease(unit_id, resident_id, status: "active")

    %{property_id: property_id}
  end

  test "reader_test reads the board views through the real query functions", %{
    property_id: property_id
  } do
    units = as_reader(fn -> Occupancy.list_unit_statuses(property_id) end)
    assert [%{unit_number: "101", status: "occupied"}] = units
  end

  test "reader_test cannot write a base table" do
    # The failed write aborts the transaction; the sandbox rolls it back at test end.
    Repo.query!("SET LOCAL ROLE reader_test")

    assert {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} =
             Repo.query(
               """
               INSERT INTO properties (name, address, city, state, units_count, created_at, updated_at)
               VALUES ('x', 'y', 'z', 'TX', 0, now(), now())
               """,
               []
             )
  end

  test "reader_test cannot read resident PII" do
    Repo.query!("SET LOCAL ROLE reader_test")

    assert {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} =
             Repo.query("SELECT * FROM residents", [])
  end
end
