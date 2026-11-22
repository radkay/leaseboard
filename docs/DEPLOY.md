# Deploy runbook

Ron's step-by-step for bringing Leaseboard up on Render and loading content.

One database, owned by Rails. The **admin** (Rails) is the only writer; the
**board** (Phoenix) reads it as the read-only role `reader_prod`. The Blueprint
(`render.yaml` at the repo root) declares three resources: `leaseboard-admin`
(Ruby), `leaseboard-board` (Docker) and one managed Postgres (`leaseboard_prod`,
owner `admin_prod`). Everything secret is `sync: false` — you set it by hand. Keep
all three in the same region.

## Plans and cost (D-020)

Paid plans for the demo period, billed per second on Render:

- Database `leaseboard_prod`: **`0.1c-256mb`** (Render's current id for the plan
  formerly called *Basic-256mb*).
- Both web services: **`0.5c-512mb`** (formerly *Starter*).

Plan ids are from Render's compute-plan reference
(https://render.com/docs/compute-plans); a paid web plan is required because the
admin uses a **pre-deploy** command, which the free plan does not run. Downgrade or
delete the resources after the job search.

## 1. Create the Blueprint

In the Render dashboard: **New → Blueprint**, connect this repository, pick the
default branch. Render reads `render.yaml` and provisions the database and the two
services, prompting for each `sync: false` secret on creation.

Set what you can now (step 3). You can set the board's `DATABASE_URL` later (step
5) — until then the board stays unhealthy, which is expected.

## 2. Create the `reader_prod` role — before the first deploy

The admin's pre-deploy runs `bin/rails db:migrate`, which triggers the
`db:privileges` hook that **grants** `reader_prod` its read surface. Migrations
never create roles (CONTRACT.md), so **`reader_prod` must already exist** or that
grant fails and the deploy fails. Create it as soon as the database is provisioned
— ideally before the admin finishes building, so the first pre-deploy succeeds.

Open a `psql` session to the database **as the owner `admin_prod`** (use the
database's *External Connection* string / the dashboard's **PSQL Command**, which
connects as `admin_prod`), then run, choosing a strong password:

```sql
CREATE ROLE reader_prod LOGIN PASSWORD '<reader_prod-password>';
```

Keep that password — the board's `DATABASE_URL` uses it (step 5). The privileges
script grants everything else (CONNECT, SELECT on the views, EXECUTE on the status
function); the role needs only `LOGIN` and a password here.

**Do not create `reader_prod` from Render's dashboard.** A user added through the
dashboard becomes the database's *default user*, which would repoint the admin's
`DATABASE_URL` (`fromDatabase`) at the read-only role and break writes. Create it
only with the SQL above, as `admin_prod`.

If `CREATE ROLE` is **refused** (e.g. `admin_prod` lacks `CREATEROLE`): **stop and
ask Ron.** Render's docs do not state whether the managed-database user can create
roles, so this runbook does not assume it; don't work around it from the dashboard.

**Verified 2026-11-22:** `admin_prod` has `CREATEROLE` on Render, and `CREATE ROLE
reader_prod` succeeded as `admin_prod`.

> If the admin's first deploy already failed at the privileges step because
> `reader_prod` wasn't there yet, that's fine: create the role, then redeploy the
> admin (step 4).

## 3. Set the secrets

Generate and set these per service (**Environment** tab). The admin's `DATABASE_URL`
is wired from the database automatically — don't set it.

**leaseboard-admin:**

| Variable | How to get it |
|---|---|
| `SECRET_KEY_BASE` | `cd apps/admin && bin/rails secret` |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | your choice — HTTP basic auth for the admin |
| `SANITY_PROJECT_ID` | `0dws7msn` |
| `SANITY_DATASET` | `production` |
| `SANITY_API_VERSION` | e.g. `2024-01-01` (optional; unset ⇒ fallback copy, no network call) |

**leaseboard-board:**

| Variable | How to get it |
|---|---|
| `SECRET_KEY_BASE` | `cd apps/board && mix phx.gen.secret` (a **different** value from the admin's) |
| `PHX_HOST` | the board service's hostname, e.g. `leaseboard-board.onrender.com` (Render shows it once the service exists) — used for `check_origin` and the canonical URL |
| `DATABASE_URL` | the `reader_prod` connection string — build it in step 5 |

## 4. First deploy (migrations + privileges)

With `reader_prod` created, let the admin deploy (or redeploy it). Its pre-deploy
runs `bin/rails db:migrate`, which migrates the schema and — through the
`db:privileges` hook — grants `reader_prod` its read surface and locks down the
status function (`apps/admin/DEPLOY.md`). The admin should go healthy at `/up`.

**Verified 2026-11-22:** `privileges.sql` revokes `CONNECT` from `PUBLIC`, and
Render's database metrics (Active Connections) kept reporting afterward. Render's
monitoring connects as the owner, so no extra grant for a Render monitoring role is
needed.

## 5. Point the board at `reader_prod`

Open **leaseboard-db** and copy its **Internal Database URL** (host, port and
database name — that URL is the owner's). Build the board's `DATABASE_URL` by
swapping in the read-only role and its password from step 2:

```
postgres://reader_prod:<reader_prod-password>@<internal-host>:<port>/leaseboard_prod
```

Set it as `DATABASE_URL` on **leaseboard-board** and redeploy. Use the **internal**
host so the board reaches the database over Render's private network. The board
connects read-only and its `Postgrex.Notifications` listener uses the same URL, so
a lease change in the admin reaches the board within a second.

## 6. Seed the demo data — once

`db:seed` is destructive (it clears and regenerates), so it is gated. From a
**leaseboard-admin** shell, run it once:

```sh
ALLOW_SEED_RESET=1 bin/rails db:seed
```

Don't make `ALLOW_SEED_RESET` a persistent variable, and never add seeding to the
build or pre-deploy commands — a redeploy would wipe live data.

## 7. Import the Sanity listing content

Loads the three `propertyListing` documents and their placeholder images into the
Sanity dataset. Run once, after the seed (the slugs must match the seeded
properties).

Prerequisites: the Sanity project (`0dws7msn`) and dataset (`production`), and write
access. Authenticate with `npx sanity login`, or export a write token as
`SANITY_IMPORT_TOKEN` (the variable the import CLI reads; see
`npx sanity dataset import --help`).

From the `studio/` directory:

```sh
npx sanity dataset import seed-content/listings.ndjson --dataset production --replace
```

`--replace` upserts by document id (`listing-<slug>`), so re-running is safe. The
image references are `image@file://./images/...`, resolved against `seed-content/`,
so run the import from `studio/` exactly as above. There is no `--dry-run` flag; run
`npx sanity dataset import --help` for the options. See `studio/seed-content/README.md`
to regenerate the content.

## 8. Verify

- **Admin** — `https://<admin-host>/up` returns 200; the admin UI loads behind
  basic auth; `/rent_roll` works.
- **Board** — `https://<board-host>/healthz` returns `ok`; `/` lists the three
  properties with KPIs; a property page shows the unit grid and charts.
- **Live update** — give notice on a lease in the admin and watch the board page
  update within a second.
- **Listings** — `https://<admin-host>/listings/<slug>` renders the Sanity content;
  with `SANITY_*` unset it still renders fallback copy.
