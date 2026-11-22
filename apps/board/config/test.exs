import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :board, Board.Repo,
  username: System.get_env("POSTGRES_USER", "leaseboard"),
  password: System.get_env("POSTGRES_PASSWORD", "local_dev_only"),
  hostname: System.get_env("POSTGRES_HOST", "db"),
  database: "board_test#{System.get_env("MIX_TEST_PARTITION")}",
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
