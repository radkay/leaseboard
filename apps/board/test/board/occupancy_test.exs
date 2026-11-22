defmodule Board.OccupancyTest do
  # Reads the Rails-owned views through the schemas. Data is seeded with raw SQL
  # (the board has no write schemas); the views derive status in the same
  # transaction, so the sandbox sees it.
  use Board.DataCase, async: true

  alias Board.Occupancy

  setup do
    property_id = insert_property(name: "Maple Court", slug: "maple-court")
    resident_id = insert_resident()

    occupied = insert_unit(property_id, number: "101", bedrooms: 2, market_rent: "1500.00")

    insert_lease(occupied, resident_id,
      start_offset: -30,
      end_offset: 300,
      rent: "1450.00",
      status: "active"
    )

    # A second, never-leased unit so the KPIs cover more than one status.
    _vacant = insert_unit(property_id, number: "102", bedrooms: 0, market_rent: "1100.00")

    %{property_id: property_id}
  end

  test "list_properties_with_kpis/0 returns properties with their KPI row", %{
    property_id: property_id
  } do
    assert [property] = Occupancy.list_properties_with_kpis()
    assert property.id == property_id
    assert property.name == "Maple Court"
    assert property.sanity_slug == "maple-court"

    kpis = property.kpis
    assert kpis.total_units == 2
    assert kpis.occupied == 1
    assert kpis.vacant_available == 1
    assert Decimal.equal?(kpis.occupancy_pct, "50.00")
    assert Decimal.equal?(kpis.leased_pct, "50.00")
    assert kpis.available_units == 1
  end

  test "get_property!/1 loads the property and get_property_kpis/1 its KPIs", %{
    property_id: property_id
  } do
    assert Occupancy.get_property!(property_id).name == "Maple Court"
    assert Occupancy.get_property_kpis(property_id).total_units == 2

    assert_raise Ecto.NoResultsError, fn -> Occupancy.get_property!(-1) end
    assert Occupancy.get_property_kpis(-1) == nil
  end

  test "list_unit_statuses/1 maps the status view, ordered by unit number", %{
    property_id: property_id
  } do
    assert [occupied, vacant] = Occupancy.list_unit_statuses(property_id)

    assert occupied.unit_number == "101"
    assert occupied.status == "occupied"
    assert occupied.bedrooms == 2
    assert Decimal.equal?(occupied.market_rent, "1500.00")
    assert Decimal.equal?(occupied.current_monthly_rent, "1450.00")
    assert Date.compare(occupied.current_lease_end_date, Date.utc_today()) == :gt

    assert vacant.unit_number == "102"
    assert vacant.status == "vacant_available"
    assert vacant.current_monthly_rent == nil
  end

  defp insert_property(opts) do
    single_id!(
      "INSERT INTO properties (name, address, city, state, sanity_slug, units_count, created_at, updated_at)
       VALUES ($1, '1 Main St', 'Austin', 'TX', $2, 0, now(), now()) RETURNING id",
      [Keyword.fetch!(opts, :name), Keyword.fetch!(opts, :slug)]
    )
  end

  defp insert_resident do
    single_id!(
      "INSERT INTO residents (first_name, last_name, email, phone, created_at, updated_at)
       VALUES ('Test', 'Resident', 'test.resident@example.com', '555-0100', now(), now()) RETURNING id",
      []
    )
  end

  defp insert_unit(property_id, opts) do
    single_id!(
      "INSERT INTO units (property_id, number, bedrooms, bathrooms, sq_ft, market_rent, created_at, updated_at)
       VALUES ($1, $2, $3, 1.0, 850, $4, now(), now()) RETURNING id",
      [
        property_id,
        Keyword.fetch!(opts, :number),
        Keyword.fetch!(opts, :bedrooms),
        Decimal.new(Keyword.fetch!(opts, :market_rent))
      ]
    )
  end

  defp insert_lease(unit_id, resident_id, opts) do
    Repo.query!(
      "INSERT INTO leases (unit_id, resident_id, start_date, end_date, monthly_rent, status, created_at, updated_at)
       VALUES ($1, $2, CURRENT_DATE + $3::integer, CURRENT_DATE + $4::integer, $5, $6, now(), now())",
      [
        unit_id,
        resident_id,
        Keyword.fetch!(opts, :start_offset),
        Keyword.fetch!(opts, :end_offset),
        Decimal.new(Keyword.fetch!(opts, :rent)),
        Keyword.fetch!(opts, :status)
      ]
    )
  end

  defp single_id!(sql, params) do
    %Postgrex.Result{rows: [[id]]} = Repo.query!(sql, params)
    id
  end
end
