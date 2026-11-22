defmodule Board.OccupancyChartsTest do
  use Board.DataCase, async: true

  alias Board.Occupancy
  alias Board.Test.Seeds

  describe "list_unit_type_kpis/1" do
    test "returns one row per bedroom bucket, ordered studio-first" do
      property_id = Seeds.insert_property()
      resident_id = Seeds.insert_resident()

      # Two studios (one occupied), one 2-bedroom (occupied).
      studio_a = Seeds.insert_unit(property_id, number: "S1", bedrooms: 0)
      _studio_b = Seeds.insert_unit(property_id, number: "S2", bedrooms: 0)
      two_bed = Seeds.insert_unit(property_id, number: "201", bedrooms: 2)

      Seeds.insert_lease(studio_a, resident_id, status: "active")
      Seeds.insert_lease(two_bed, resident_id, status: "active")

      [studio, two] = as_reader(fn -> Occupancy.list_unit_type_kpis(property_id) end)

      assert studio.bedrooms == 0
      assert studio.total_units == 2
      assert studio.occupied == 1
      assert Decimal.equal?(studio.occupancy_pct, "50.00")

      assert two.bedrooms == 2
      assert two.total_units == 1
      assert Decimal.equal?(two.occupancy_pct, "100.00")
    end
  end

  describe "list_lease_expirations/1" do
    test "returns a dense 12-month series split into renewed/re-let and open" do
      property_id = Seeds.insert_property()
      resident_id = Seeds.insert_resident()

      # Unit A: current lease ends in ~3 months, with a signed follow-on → renewed.
      unit_a = Seeds.insert_unit(property_id, number: "A")
      Seeds.insert_lease(unit_a, resident_id, status: "active", start_offset: -30, end_offset: 90)

      Seeds.insert_lease(unit_a, resident_id,
        status: "pending",
        start_offset: 95,
        end_offset: 460
      )

      # Unit B: current lease ends in ~4 months, no follow-on → open.
      unit_b = Seeds.insert_unit(property_id, number: "B")

      Seeds.insert_lease(unit_b, resident_id,
        status: "active",
        start_offset: -30,
        end_offset: 120
      )

      series = as_reader(fn -> Occupancy.list_lease_expirations(property_id) end)

      assert length(series) == 12
      assert hd(series).month == Date.beginning_of_month(Date.utc_today())
      assert series == Enum.sort_by(series, & &1.month, Date)

      assert Enum.sum_by(series, & &1.expiring_total) == 2
      assert Enum.sum_by(series, & &1.expiring_renewed_or_relet) == 1
      assert Enum.sum_by(series, & &1.expiring_open) == 1

      for row <- series do
        assert row.expiring_total == row.expiring_renewed_or_relet + row.expiring_open
      end
    end
  end
end
