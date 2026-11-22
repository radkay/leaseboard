defmodule Board.LeaseChangeListenerTest do
  # Real database connections (a LISTEN connection and a NOTIFY sender), not the
  # Ecto sandbox: NOTIFY is only delivered on commit, and the sandbox rolls back.
  use ExUnit.Case, async: false

  alias Board.LeaseChangeListener

  setup do
    conn_opts = LeaseChangeListener.repo_connection_opts()

    # A plain, auto-committing connection to emit NOTIFY, standing in for Rails.
    {:ok, rails} = Postgrex.start_link(conn_opts)

    start_supervised!({LeaseChangeListener, connection: conn_opts, pubsub: Board.PubSub})

    %{rails: rails}
  end

  test "rebroadcasts a lease_changed notification on the property topic", %{rails: rails} do
    Phoenix.PubSub.subscribe(Board.PubSub, "property:42")

    Postgrex.query!(rails, "SELECT pg_notify('lease_changed', $1)", ["42"])

    assert_receive {:lease_changed, "42"}, 2_000
  end

  test "only broadcasts on the notifying property's topic", %{rails: rails} do
    Phoenix.PubSub.subscribe(Board.PubSub, "property:7")

    Postgrex.query!(rails, "SELECT pg_notify('lease_changed', $1)", ["42"])

    refute_receive {:lease_changed, _}, 500
  end
end
