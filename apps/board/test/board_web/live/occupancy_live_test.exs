defmodule BoardWeb.OccupancyLiveTest do
  # Non-async so the sandbox runs in shared mode and the LiveView process sees
  # the seeded data (the endpoint has no SQL sandbox plug for async allowances).
  use BoardWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Board.Test.Seeds

  describe "index (/)" do
    test "lists properties with their KPIs", %{conn: conn} do
      seed_occupied(name: "Maple Court", number: "101")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Occupancy board"
      assert html =~ "Maple Court"
      # One occupied unit → 100% occupancy and leased.
      assert html =~ "100.00%"
    end

    test "re-queries when a lease changes on a listed property", %{conn: conn} do
      %{property_id: property_id, lease_id: lease_id} = seed_occupied(number: "101")

      {:ok, view, _html} = live(conn, ~p"/")
      assert render(view) =~ "100.00%"

      # End the lease: the unit becomes vacant_available, so occupancy drops to 0.
      Seeds.set_lease_status(lease_id, "ended")
      broadcast_lease_changed(property_id)

      assert render(view) =~ "0.00%"
    end
  end

  describe "show (/properties/:id)" do
    test "renders the unit grid coloured by status, with a legend", %{conn: conn} do
      %{property_id: property_id} = seed_occupied(name: "Maple Court", number: "101")

      {:ok, _view, html} = live(conn, ~p"/properties/#{property_id}")

      assert html =~ "Maple Court"
      # The legend lists every status label...
      assert html =~ "Vacant · available"
      # ...and the occupied unit carries its status in an accessible label.
      assert html =~ "Unit 101, Occupied"
    end

    test "flips a unit's status on a lease_changed notification", %{conn: conn} do
      %{property_id: property_id, lease_id: lease_id} = seed_occupied(number: "101")

      {:ok, view, _html} = live(conn, ~p"/properties/#{property_id}")
      assert render(view) =~ "Unit 101, Occupied"

      # Give notice: the unit moves to on_notice.
      Seeds.set_lease_status(lease_id, "notice_given", notice_date: Date.utc_today())
      broadcast_lease_changed(property_id)

      html = render(view)
      assert html =~ "Unit 101, On notice"
      refute html =~ "Unit 101, Occupied"
    end
  end

  # Seeds one property with a single active-lease (occupied) unit.
  defp seed_occupied(opts) do
    property_id = Seeds.insert_property(Keyword.take(opts, [:name, :slug]))
    resident_id = Seeds.insert_resident()
    unit_id = Seeds.insert_unit(property_id, number: Keyword.fetch!(opts, :number))
    lease_id = Seeds.insert_lease(unit_id, resident_id, status: "active")

    %{property_id: property_id, unit_id: unit_id, lease_id: lease_id}
  end

  # Stands in for Board.LeaseChangeListener, which would broadcast this on a real
  # NOTIFY (covered in lease_change_listener_test.exs).
  defp broadcast_lease_changed(property_id) do
    Phoenix.PubSub.broadcast(
      Board.PubSub,
      "property:#{property_id}",
      {:lease_changed, to_string(property_id)}
    )
  end
end
