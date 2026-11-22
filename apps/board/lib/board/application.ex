defmodule Board.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Start to serve requests, typically the last entry
    children =
      [
        BoardWeb.Telemetry,
        Board.Repo,
        {DNSCluster, query: Application.get_env(:board, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Board.PubSub}
      ] ++
        listeners() ++
        [BoardWeb.Endpoint]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Board.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # The Postgrex LISTEN connection is disabled in test so each test starts its
  # own listener and controls it (config/test.exs sets `start_listener: false`).
  defp listeners do
    if Application.get_env(:board, :start_listener, true) do
      [Board.LeaseChangeListener]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
