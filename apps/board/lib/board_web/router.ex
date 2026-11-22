defmodule BoardWeb.Router do
  use BoardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BoardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check for the platform (Render). No browser pipeline: it needs no
  # session, CSRF or layout — just a fast 200.
  scope "/", BoardWeb do
    get "/healthz", HealthController, :show
  end

  scope "/", BoardWeb do
    pipe_through :browser

    live "/", OccupancyLive.Index
    live "/properties/:id", OccupancyLive.Show
  end

  # Other scopes may use custom stacks.
  # scope "/api", BoardWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:board, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BoardWeb.Telemetry
    end
  end
end
