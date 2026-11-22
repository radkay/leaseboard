# Deploy runbook

Ron's step-by-step for bringing Leaseboard up on Render and loading content.

The Blueprint (`render.yaml` at the repo root) declares three resources: the
**admin** web service (Rails, the only writer), the **board** web service
(Phoenix, read-only, Docker), and one managed **Postgres**. Everything secret is
`sync: false` — you set it by hand. Keep all three in the same region.

## 1. Create the Blueprint

1. In the Render dashboard: **New → Blueprint**, connect this repository, and pick
   the default branch. Render reads `render.yaml` and proposes the three resources.
2. Before the first deploy, set the secrets below (step 2). Deploys that are missing
   a required variable will fail cleanly — set it and redeploy.

## 2. Set the secrets

Generate and set these in the dashboard (each service has its own **Environment**):

**Shared value — the `reader_prod` password.** Pick a strong password. You create the
read-only `reader_prod` role with it before the first deploy (step 3), and the board
connects with the **same** value (step 4). It is **not** an admin variable: the admin's
`db:privileges` grants `reader_prod` without ever needing its password.

**leaseboard-admin:**

| Variable | How to get it |
|---|---|
| `SECRET_KEY_BASE` | `cd apps/admin && bin/rails secret` |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | your choice — HTTP basic auth for the admin |
| `SANITY_PROJECT_ID`, `SANITY_DATASET`, `SANITY_API_VERSION` | optional; from your Sanity project. Unset ⇒ the listing page shows fallback copy and makes no network call |

(`DATABASE_URL` is wired from the database automatically — don't set it.)

**leaseboard-board:**

| Variable | How to get it |
|---|---|
| `SECRET_KEY_BASE` | `cd apps/board && mix phx.gen.secret` (a **different** value from the admin's) |
| `PHX_HOST` | the board service's hostname, e.g. `leaseboard-board.onrender.com` (Render shows it after the service is created). Used for `check_origin` and the canonical URL |
| `DATABASE_URL` | the `reader_prod` connection string — build it in step 4 |

## 3. Create `reader_prod`, then first deploy (admin + database)

The board connects read-only as `reader_prod`. Migrations never create roles
(CONTRACT.md), so create it once, by hand, before the first deploy. Open
**leaseboard-db** → **PSQL Command** (it connects as the database's `admin_prod`
owner) and run:

```sql
CREATE ROLE reader_prod LOGIN PASSWORD '<the reader_prod password>';
```

(This needs the owner to have `CREATEROLE`; Render's primary user does. If it is
refused, create `reader_prod` from the Render dashboard instead.)

Then let the Blueprint deploy. On the admin, the **pre-deploy** command runs
`bin/rails db:migrate`, which creates the schema and the status/KPI views and then
applies `apps/admin/db/privileges.sql` (via the `db:privileges` hook) — granting
`reader_prod` exactly the board's read surface and locking down the status function.
The board service may stay unhealthy until step 4 — that's expected.

## 4. Point the board at `reader_prod`

Open **leaseboard-db** and copy its **Internal Database URL** (that's the owner
connection — host, port and database name). Build the board's `DATABASE_URL` by
swapping the user and password for the read-only role:

```
postgres://reader_prod:<the reader_prod password>@<internal-host>:<port>/<database>
```

Set it as `DATABASE_URL` on **leaseboard-board** and trigger a redeploy. Use the
**internal** host so the board reaches the database over Render's private network.

The board connects read-only and its `Postgrex.Notifications` listener uses the
same URL, so a lease change in the admin flows to the board within a second.

## 5. Seed the demo data — once

`db:seed` is destructive (it clears and regenerates), so it's gated. From a
**leaseboard-admin** shell, run it once:

```sh
ALLOW_SEED_RESET=1 bin/rails db:seed
```

Don't make `ALLOW_SEED_RESET` a persistent variable, and never add seeding to the
build or release commands — a redeploy would wipe live data.

## 6. Import the Sanity listing content

Loads the three `propertyListing` documents (one per seeded property) and their
placeholder images into the Studio's dataset. Run this **once**, after the Rails
seed has created the properties (the slugs must match) — content and database are
independent, so the order between them doesn't otherwise matter.

Prerequisites:

- A Sanity project and dataset (e.g. `production`) exist, and the Studio is
  configured with the project id (`studio/.env.local` locally, or the deploy
  environment).
- You're authenticated: `npx sanity login`, or set `SANITY_AUTH_TOKEN` to a
  token with write access to the dataset.

From the `studio/` directory:

```sh
# Dry run first — validates the documents and asset references without writing:
npx sanity dataset import seed-content/listings.ndjson production --replace --dry-run

# Then the real import:
npx sanity dataset import seed-content/listings.ndjson production --replace
```

Notes:

- `--replace` upserts by document id (`listing-<slug>`), so re-running is safe
  and idempotent.
- The image paths in `listings.ndjson` are relative to `seed-content/`, which is
  where the import tool resolves assets from (it uses the NDJSON file's directory
  as the asset base). Run the command from `studio/` exactly as above.
- To regenerate the content first, see `studio/seed-content/README.md`.

After importing, the public listing page for each property renders its headline,
description, amenities and photos; the live available-unit count still comes from
Postgres.

## 7. Verify

- **Admin** — `https://<admin-host>/up` returns 200; the admin UI loads behind
  basic auth; `/rent_roll` works.
- **Board** — `https://<board-host>/healthz` returns `ok`; `/` lists the three
  properties with KPIs; a property page shows the unit grid and charts.
- **Live update** — give notice on a lease in the admin and watch the board page
  update within a second (this is the `scripts/demo` flow, run against production).
- **Listings** — `https://<admin-host>/listings/<slug>` renders the Sanity content;
  with `SANITY_*` unset it still renders fallback copy.
