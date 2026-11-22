defmodule BoardWeb.HealthController do
  @moduledoc """
  Liveness endpoint for the platform health check (Render). Returns `200 ok` as
  long as the web server is accepting requests. It deliberately does not touch the
  database, so a transient read-replica blip doesn't get the instance recycled.
  """
  use BoardWeb, :controller

  def show(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
