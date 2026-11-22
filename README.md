# Leaseboard

Leaseboard is a lease and occupancy tool for a small rental portfolio. It pairs a Rails admin
for managing properties, units, residents and leases with a live Phoenix LiveView occupancy
board, and a Sanity-powered public listing page for each property.

All data is synthetic.

## Live demo

- **Occupancy board:** https://leaseboard-board.onrender.com
- **Public listing page:** https://leaseboard-admin.onrender.com/listings/maple-court

> **Demo GIF placeholder.** I record a short clip here: a lease change in the admin updating
> the board live, within a second, with no page reload.

The admin is behind a login. Access is available on request: `[CONTACT]`.

## How it was built

I built Leaseboard by directing parallel AI coding agents, one per app, each branching from
`dev` and landing its work through pull requests. The work runs under layered guardrails that
GitHub enforces on its own servers: branch rules require a reviewed pull request and a green
`ci-ok` check for every change, agents run as a separate `leaseboard-bot` account, and only I
approve anything reaching `main`. Every decision and every correction is written down as it
happens, so the process is auditable, not just the result.

The process is the exhibit: [docs/APPROACH.md](docs/APPROACH.md) explains how the agent loop
and the guardrails fit together, [docs/DECISIONS.md](docs/DECISIONS.md) records each decision,
and [docs/REVIEW-LOG.md](docs/REVIEW-LOG.md) records what review caught.

## Stack and architecture

- **Rails** owns the schema and is the only writer.
- **Phoenix LiveView** reads the same database through a read-only role and never writes.
- **Live updates** flow through Postgres `LISTEN`/`NOTIFY`: a lease write notifies after
  commit, the board re-queries and re-renders over PubSub, with no polling.
- **One database per environment**, with a Rails-owned owner role and a read-only reader role.
  The databases and roles are named only in [docs/CONTRACT.md](docs/CONTRACT.md), which also
  fixes the read interface between the two apps (the views, status values, KPI definitions and
  the NOTIFY channel).
- **Sanity** holds the public listing content; the Rails listing page reads it over GROQ and
  falls back to the property record when Sanity is unavailable.
- Hosted on **Render**. The toolchain is Ruby, Elixir and Node, pinned in `.tool-versions`.

## Run it locally

The toolchain runs in a dev container (`.devcontainer/`). Open it with VS Code Dev Containers
("Clone Repository in Container Volume") or GitHub Codespaces. If you open a local folder
instead, keep the repo alone in its own parent directory; the container mounts that parent at
`/workspaces` (D-007 in [docs/DECISIONS.md](docs/DECISIONS.md)).

Rails owns the database and the board reads it, so the setup runs through Rails. From the repo
root, with the container's Postgres running and the role passwords in `.env` (copy
`.env.example`):

```sh
# 1. Create the development and test databases and their roles (as the Postgres superuser).
db/bootstrap dev
db/bootstrap test

# 2. Load the schema, apply the read-only grants, and seed ~150 units (Rails owns this).
(cd apps/admin && bundle install && \
   RAILS_ENV=development bin/rails db:schema:load db:privileges db:seed)

# 3. Start the admin (the writer) on http://localhost:3000.
(cd apps/admin && bin/rails server)

# 4. In another terminal, start the board (read-only, live) on http://localhost:4000.
(cd apps/board && mix setup && mix phx.server)
```

Then `scripts/demo` changes a lease through the admin so the board updates in front of you;
see [scripts/README.md](scripts/README.md).

## Repository map

| Path | What |
|---|---|
| `apps/admin` | Rails admin: schema and migrations, all writes, rent roll, lease actions, public listing page |
| `apps/board` | Phoenix LiveView occupancy board (read-only) |
| `studio` | Sanity Studio schema and importable listing content |
| `db` | `bootstrap`: one database and its two roles per environment |
| `docs` | SPEC, CONTRACT, DECISIONS, REVIEW-LOG, APPROACH, DEPLOY, DESIGN |
| `scripts` | the live-board demo |
| `render.yaml` | Render Blueprint (written, applied by hand) |
| `.github` | CI workflow and the contract-name guard |
| `CLAUDE.md`, `.claude` | agent instructions and the committed deny rules |

## License

Licensed under the [MIT License](LICENSE).
