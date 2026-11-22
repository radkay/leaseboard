import Config

# The board's tests run against the shared `leaseboard_test` database (CONTRACT.md
# Environments table), created by db/bootstrap and loaded by Rails — the board no
# longer creates or loads it.
#
# The Repo connects as the owner `admin_test` so the test harness can insert
# fixtures (the board itself has no write schemas). The board's real query
# functions are then run as the reader via `SET LOCAL ROLE reader_test`, inside
# the sandbox transaction, proving they work with only the reader's grants — see
# Board.DataCase.as_reader/1. The owner password comes from the environment.
#
# No MIX_TEST_PARTITION suffix: there is one shared test database, not one per
# partition.
config :board, Board.Repo,
  username: "admin_test",
  password: System.get_env("ADMIN_TEST_PASSWORD"),
  hostname: System.get_env("POSTGRES_HOST", "db"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  database: "leaseboard_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Don't start the global LISTEN connection in test; each test starts and controls
# its own Board.LeaseChangeListener (see test/board/lease_change_listener_test.exs).
config :board, start_listener: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :board, BoardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Wjgsm3VlxBjqN62Zj33gOSINA9hNUrNGhoa5Qrw/QopF5isWofetCwjt7Y9AloVt",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
