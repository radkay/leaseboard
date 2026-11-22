# Board

The read-only Phoenix occupancy board. It connects to the **shared** database that
Rails owns, as the environment's **reader** role, and never writes (CONTRACT.md
Environments table).

## Database

The board does **not** own or create a database. Rails creates and loads both
`leaseboard_dev` and `leaseboard_test` from the shared setup:

```sh
# From the repo root, as the Postgres superuser (db/bootstrap reads POSTGRES_* and
# the *_PASSWORD env vars from .env):
db/bootstrap dev
db/bootstrap test
# Then, in apps/admin, load the schema and apply the reader grants (Rails):
#   RAILS_ENV=development bin/rails db:schema:load   # loads dev AND test
#   RAILS_ENV=development bin/rails db:privileges
#   RAILS_ENV=test        bin/rails db:privileges
```

The board then connects to `leaseboard_dev` as `reader_dev` (`config/dev.exs`) and
to `leaseboard_test` as `admin_test` (`config/test.exs`). `mix setup` only installs
dependencies and builds assets — it never creates a database.

### Running the tests locally

The tests insert fixtures as the owner `admin_test`, then run the board's real
query functions as the reader via `SET LOCAL ROLE reader_test` (the read-only
proof — see `Board.DataCase.as_reader/1`). For the owner to switch to that role,
`admin_test` must be a member of `reader_test` in the **test** database. Apply it
once, as the superuser:

```sh
psql -h "$POSTGRES_HOST" -U postgres -d leaseboard_test -c 'GRANT reader_test TO admin_test'
```

(CI does this in the `board` job. See the PR for #60 — this test-only grant may be
better placed in `db/bootstrap test` so local setup is a single step; that file is
Agent A's, so it's flagged there rather than changed here.)

Then run `mix test` with the role passwords in the environment (`.env`).

## Server

* Start the Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
