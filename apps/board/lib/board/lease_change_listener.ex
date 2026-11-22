defmodule Board.LeaseChangeListener do
  @moduledoc """
  Bridges Postgres `LISTEN/NOTIFY` to Phoenix PubSub.

  Rails emits `NOTIFY lease_changed, '<property_id>'` after every lease write
  (SPEC §6, admin feature 4; CONTRACT.md §4). This process `LISTEN`s on that
  channel over a dedicated `Postgrex.Notifications` connection and rebroadcasts
  each notification on the per-property topic `"property:<id>"`, so only the
  LiveViews watching that property wake up.

  The notifications connection is linked to this process. If it drops — e.g. the
  database restarts — this process crashes and its supervisor restarts it,
  re-establishing the `LISTEN`. That restart *is* the recovery; there is no
  defensive `try/rescue` (SPEC: "Let it crash and restart").
  """
  use GenServer

  @channel "lease_changed"

  @doc """
  Starts the listener.

  Options:

    * `:connection` — Postgrex connection options for the `LISTEN` connection.
      Defaults to `repo_connection_opts/0` (the board reader's credentials).
    * `:pubsub` — the `Phoenix.PubSub` server to broadcast on. Defaults to
      `Board.PubSub`.
    * `:name` — the process name. Defaults to the module.
  """
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  The connection options Postgrex needs to open the `LISTEN` connection, taken
  from the `Board.Repo` configuration. The pool settings and the Ecto sandbox do
  not apply to a notifications connection, so only the socket-level keys are kept.
  """
  def repo_connection_opts do
    Keyword.take(Board.Repo.config(), [
      :hostname,
      :port,
      :username,
      :password,
      :database,
      :socket_options,
      :ssl,
      :ssl_opts,
      :parameters
    ])
  end

  @impl true
  def init(opts) do
    pubsub = Keyword.get(opts, :pubsub, Board.PubSub)
    conn_opts = Keyword.get(opts, :connection) || repo_connection_opts()

    {:ok, conn} = Postgrex.Notifications.start_link(conn_opts)
    {:ok, _ref} = Postgrex.Notifications.listen(conn, @channel)

    {:ok, %{conn: conn, pubsub: pubsub}}
  end

  @impl true
  def handle_info({:notification, _conn, _ref, @channel, property_id}, state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "property:#{property_id}",
      {:lease_changed, property_id}
    )

    {:noreply, state}
  end
end
