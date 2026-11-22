defmodule BoardWeb.OccupancyUITest do
  # Non-async so the sandbox is shared with the LiveView process.
  use BoardWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Board.Test.Seeds

  setup do
    property_id = Seeds.insert_property(name: "Maple Court")
    resident_id = Seeds.insert_resident()

    # 1 BR: one occupied, one vacant. 2 BR: occupied with a signed follow-on.
    occupied = Seeds.insert_unit(property_id, number: "101", bedrooms: 1)
    _vacant = Seeds.insert_unit(property_id, number: "102", bedrooms: 1)
    renewing = Seeds.insert_unit(property_id, number: "201", bedrooms: 2)

    Seeds.insert_lease(occupied, resident_id, status: "active", end_offset: 200)
    renewing_lease = Seeds.insert_lease(renewing, resident_id, status: "active", end_offset: 60)

    Seeds.insert_lease(renewing, resident_id,
      status: "pending",
      start_offset: 65,
      end_offset: 430
    )

    %{
      property_id: property_id,
      renewing_unit: renewing,
      renewing_lease: renewing_lease
    }
  end

  describe "index charts" do
    test "each card renders the occupancy donut and status bar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Donut/status-bar accessible summaries carry the exact counts.
      assert html =~ "2 occupied"
      assert html =~ "1 vacant · available"
      assert html =~ "of 3 units"
      # The doughnut is server-rendered SVG, not a library.
      assert html =~ "<svg"
    end
  end

  describe "show charts" do
    test "renders occupancy-by-unit-type and expirations with their data tables", %{
      conn: conn,
      property_id: property_id
    } do
      {:ok, _view, html} = live(conn, ~p"/properties/#{property_id}")

      # Unit-type chart: 1 BR is 50% occupied, 2 BR is 100%.
      assert html =~ "Occupancy and leased percent by unit type"
      assert html =~ "1 BR"
      assert html =~ "2 BR"
      assert html =~ "50.00%"
      assert html =~ "100.00%"

      # Expirations chart text alternative: one renewed, one open across the window.
      assert html =~ "Lease expirations by month"
      assert html =~ "Renewed or re-let"
    end
  end

  describe "interactions" do
    test "clicking a legend status filters the grid", %{conn: conn, property_id: property_id} do
      {:ok, view, _html} = live(conn, ~p"/properties/#{property_id}")

      html = view |> element("button[phx-value-status='occupied']") |> render_click()

      # The clicked status is pressed and the non-matching cells are dimmed.
      assert html =~ ~s(aria-pressed="true")
      assert html =~ "opacity-25"
    end

    test "clicking a unit opens its detail panel, with no resident identity", %{
      conn: conn,
      property_id: property_id,
      renewing_unit: renewing_unit
    } do
      {:ok, view, _html} = live(conn, ~p"/properties/#{property_id}")

      html = render_click(view, "select_unit", %{"id" => to_string(renewing_unit)})

      assert html =~ "Unit 201 detail"
      assert html =~ "Next lease start"
      assert html =~ "2 BR"
      # The status view exposes no resident fields.
      refute html =~ "resident"

      html = render_click(view, "close_unit", %{})
      refute html =~ "Unit 201 detail"
    end
  end

  describe "live update" do
    test "a lease_changed notification updates the donut and flashes the changed unit", %{
      conn: conn,
      property_id: property_id,
      renewing_lease: renewing_lease
    } do
      {:ok, view, _html} = live(conn, ~p"/properties/#{property_id}")
      assert render(view) =~ "2 occupied"

      # End the renewing unit's active lease: it becomes vacant (its pending lease
      # starts in the future), so occupancy drops.
      Seeds.set_lease_status(renewing_lease, "ended")
      broadcast_lease_changed(property_id)

      html = render(view)
      # Donut summary updated.
      assert html =~ "1 occupied"
      # The changed unit flashes and shows its new status.
      assert html =~ "unit-flash"
      assert html =~ "Unit 201, Vacant · rented"

      # The flash clears on the scheduled message.
      send(view.pid, :clear_flash)
      refute render(view) =~ "unit-flash"
    end
  end

  defp broadcast_lease_changed(property_id) do
    Phoenix.PubSub.broadcast(
      Board.PubSub,
      "property:#{property_id}",
      {:lease_changed, to_string(property_id)}
    )
  end
end
