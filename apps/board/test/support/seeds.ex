defmodule Board.Test.Seeds do
  @moduledoc """
  Minimal raw-SQL seeding for board tests. The board has no write schemas (Rails
  owns the schema), so fixtures are inserted with plain SQL through the sandbox
  connection; the Rails-owned views then derive status in the same transaction.
  """
  alias Board.Repo

  def insert_property(opts \\ []) do
    single_id!(
      "INSERT INTO properties (name, address, city, state, sanity_slug, units_count, created_at, updated_at)
       VALUES ($1, '1 Main St', 'Austin', 'TX', $2, 0, now(), now()) RETURNING id",
      [Keyword.get(opts, :name, "Test Property"), Keyword.get(opts, :slug, "test-property")]
    )
  end

  def insert_resident do
    single_id!(
      "INSERT INTO residents (first_name, last_name, email, phone, created_at, updated_at)
       VALUES ('Test', 'Resident', 'test.resident@example.com', '555-0100', now(), now()) RETURNING id",
      []
    )
  end

  def insert_unit(property_id, opts) do
    single_id!(
      "INSERT INTO units (property_id, number, bedrooms, bathrooms, sq_ft, market_rent, created_at, updated_at)
       VALUES ($1, $2, $3, 1.0, 850, $4, now(), now()) RETURNING id",
      [
        property_id,
        Keyword.fetch!(opts, :number),
        Keyword.get(opts, :bedrooms, 1),
        Decimal.new(Keyword.get(opts, :market_rent, "1200.00"))
      ]
    )
  end

  def insert_lease(unit_id, resident_id, opts) do
    Repo.query!(
      "INSERT INTO leases (unit_id, resident_id, start_date, end_date, monthly_rent, status, created_at, updated_at)
       VALUES ($1, $2, CURRENT_DATE + $3::integer, CURRENT_DATE + $4::integer, $5, $6, now(), now())
       RETURNING id",
      [
        unit_id,
        resident_id,
        Keyword.get(opts, :start_offset, -30),
        Keyword.get(opts, :end_offset, 300),
        Decimal.new(Keyword.get(opts, :rent, "1150.00")),
        Keyword.fetch!(opts, :status)
      ]
    )
    |> single_row_id()
  end

  @doc "Sets a lease's status (and optional notice date), e.g. to simulate giving notice or ending."
  def set_lease_status(lease_id, status, opts \\ []) do
    Repo.query!(
      "UPDATE leases SET status = $2, notice_date = $3, updated_at = now() WHERE id = $1",
      [lease_id, status, Keyword.get(opts, :notice_date)]
    )

    :ok
  end

  defp single_id!(sql, params), do: single_row_id(Repo.query!(sql, params))

  defp single_row_id(%Postgrex.Result{rows: [[id]]}), do: id
end
