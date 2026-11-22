# Deploying the admin (Rails) to Render

The admin is a standard Rails 8 app served by Puma. It needs a PostgreSQL database and a
handful of environment variables. Nothing is hard-coded: every secret and connection
detail comes from the environment. These are the commands and variables a Render web
service (or `render.yaml`) should use — Render itself is configured by Agent B.

## Commands

| Step | Command |
| --- | --- |
| **Build** | `SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile` |
| **Release** (pre-deploy, runs each deploy) | `bin/rails db:migrate` |
| **Start** | `bin/rails server` |

Notes:
- The build precompiles assets with Propshaft. `SECRET_KEY_BASE_DUMMY=1` lets the build
  boot the production environment without a real secret (none is needed to compile assets).
- `bin/rails server` reads `config/puma.rb`, which binds to `PORT` (Render sets it) and
  `RAILS_MAX_THREADS` threads.
- The release step runs migrations before the new version takes traffic. One migration
  creates the read-only `board_reader` role and reads `BOARD_READER_PASSWORD` from the
  environment, so that variable must be present for `db:migrate`.

## Environment variables

Required:

| Variable | Purpose |
| --- | --- |
| `RAILS_ENV` | `production` |
| `SECRET_KEY_BASE` | Rails session/signing key. Generate once with `bin/rails secret`. (We don't use encrypted credentials, so no `RAILS_MASTER_KEY` is needed.) |
| `DATABASE_URL` | Full Postgres connection URL. Render's managed Postgres supplies it; `config/database.yml` reads it directly in production. |
| `BOARD_READER_PASSWORD` | Password for the read-only `board_reader` role the migration provisions; Phoenix connects with the same value. |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | HTTP basic auth for the whole admin (the public `/listings/:slug` page is the only exception). |

Optional:

| Variable | Purpose |
| --- | --- |
| `SANITY_PROJECT_ID`, `SANITY_DATASET`, `SANITY_API_VERSION` | Enable live listing content from Sanity. With any of them unset, the listing page renders fallback copy from the property record and makes no network call. |
| `RAILS_MAX_THREADS` | Puma threads (and DB pool). Default 3. |
| `WEB_CONCURRENCY` | Puma worker processes. Default 1. |

## Health check

`GET /up` returns 200 when the app boots cleanly, 500 otherwise. It is public (outside
basic auth), so point Render's health check at `/up`.

## Seeding — once, after the first deploy

`db:seed` is **destructive**: it deletes all properties, units, residents and leases, then
regenerates the demo data. It therefore refuses to run in production unless
`ALLOW_SEED_RESET=1` is set (enforced by `lib/seed_reset.rb`).

After the first successful deploy and migration, seed the demo data **once** from a Render
shell:

```sh
ALLOW_SEED_RESET=1 bin/rails db:seed
```

Do not set `ALLOW_SEED_RESET` as a persistent service variable, and never add seeding to
the build or release commands — a redeploy would wipe live data.
