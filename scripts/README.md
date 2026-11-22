# scripts

## `demo` — live board demo

Changes one lease through Rails's real lease actions so the Phoenix board updates
in front of you, with pauses between steps. This is what the README GIF films.

It picks a currently-occupied unit, then:

1. **Gives notice** → the unit flips to **On notice** (amber) and briefly flashes.
2. **Signs a new lease** starting after the current term → the unit becomes
   **On notice · re-let** (teal).

Each change is a committed lease write, so Rails emits `NOTIFY lease_changed` and
the board re-renders live over PubSub — no page reloads, no polling.

### How it works

Both apps must talk to **one** database — the one the board reads. In dev that's
`board_dev` (`apps/board/config/dev.exs`). Rails owns the schema (one writer), so
the board's database is created and seeded *from Rails*, pointed at it with
`DATABASE_URL`. `scripts/demo` then runs the lease actions against that same
database with `bin/rails runner`.

### Run it locally

From the repo root, with Postgres up (the devcontainer's `db` service):

```sh
# 1. Create and seed the board's dev database from Rails (loads the schema and
#    ~150 units with a realistic status mix):
(cd apps/admin && \
  DATABASE_URL=postgres://leaseboard:local_dev_only@db:5432/board_dev \
  bin/rails db:prepare)

# 2. Start the board (it reads board_dev by default):
(cd apps/board && mix phx.server)        # → http://localhost:4000

# 3. In another terminal, run the demo and watch the board:
./scripts/demo
```

Open the property URL the script prints (e.g. `/properties/1`) before it moves on,
or raise the pause to give yourself time to switch windows.

### Options (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `DEMO_PAUSE_SECONDS` | `6` | Seconds to wait between steps — raise it for filming. |
| `BOARD_DATABASE` | `board_dev` | The database the board reads (and the demo writes to). |
| `POSTGRES_HOST` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `db` / `leaseboard` / `local_dev_only` | Connection parts. |

The demo builds `DATABASE_URL` from these and exports it, overriding any inherited
one — the devcontainer ships a `DATABASE_URL` with no database name, which would
otherwise send Rails to its own `admin_development`.

Re-running is safe: each run picks a different occupied unit (the previous one is
now on notice).
