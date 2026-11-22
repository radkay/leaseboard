defmodule BoardWeb.PageControllerTest do
  use BoardWeb.ConnCase

  # `/` now serves the occupancy board LiveView (BoardWeb.OccupancyLive.Index),
  # not the generated Phoenix landing page. A plain GET returns the LiveView's
  # static render; the connected behaviour is covered in occupancy_live_test.exs.
  test "GET / serves the occupancy board", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Occupancy board"
  end
end
