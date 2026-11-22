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

There is **one** database, `leaseboard_dev`. Rails owns and writes it (as
`admin_dev`); the board reads it (as `reader_dev`, `apps/board/config/dev.exs`).
The demo just runs the admin's lease actions against its own development database
with `bin/rails runner` — no `DATABASE_URL` override, no second database.

### Run it locally

With Postgres up (the devcontainer's `db` service):

```sh
# 1. Set up the shared development database (bootstrap + schema + privileges —
#    see apps/board/README.md), then seed it with ~150 units:
db/bootstrap dev
(cd apps/admin && RAILS_ENV=development bin/rails db:schema:load db:privileges db:seed)

# 2. Start the board (reads leaseboard_dev as reader_dev):
(cd apps/board && mix phx.server)        # → http://localhost:4000

# 3. In another terminal, run the demo and watch the board:
./scripts/demo
```

Open the property URL the script prints (e.g. `/properties/1`) before it moves on,
or raise the pause to give yourself time to switch windows.

### Options

| Variable | Default | Purpose |
|---|---|---|
| `DEMO_PAUSE_SECONDS` | `6` | Seconds to wait between steps — raise it for filming. |

Re-running is safe: each run picks a different occupied unit (the previous one is
now on notice).
