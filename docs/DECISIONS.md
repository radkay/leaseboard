# Decision Log

One entry per decision. Newest at the bottom. Quote Ron's words when he makes the call.

## Template
### D-### · YYYY-MM-DD · Short title
- **Decision:**
- **Options considered:**
- **Why:**
- **Ron:** "…"

---

### D-000 · 2026-11-20 · Project framing
- **Decision:** Rails admin (only writer) + Phoenix LiveView read-only board + Sanity listings, on Render with one Postgres. Databricks kept as a separate project.
- **Options considered:** a single Rails app; a single Phoenix app; Rails/Phoenix on top of Databricks.
- **Why:** shows each framework at its strength, keeps the architecture boring and PaaS-hosted, and keeps each portfolio piece focused on one point.
- **Ron:** "Agreed. Keep them separated. Rails/Elixir this weekend."

### D-001 · 2026-11-21 · Development environment: Dev Container
- **Decision:** Develop in a VS Code Dev Container (Docker Desktop on WSL2), defined in `.devcontainer/` and committed, so the same environment also runs in GitHub Codespaces.
- **Options considered:** (a) WSL2 Ubuntu with a local toolchain: fastest to set up, but the environment isn't captured in the repo. (b) Dev Container: reproducible environment as code that reviewers can open in one click, at the cost of more setup today. (c) Native Windows: rejected, because of poor Rails support.
- **Why:** Matches Linux production on Render, pins every tool version in the repo, and lets a reviewer run the app with nothing installed. WSL2 is required for (b) anyway.
- **Ron:** "The easy path isn't necessarily the right path." "I will put in the time to make this right."

### D-002 · 2026-11-21 · Repository: radkay/leaseboard, public
- **Decision:** Public repo `radkay/leaseboard` on Ron's personal GitHub account. History starts from a single clean root commit.
- **Options considered:** a GitHub organization; Ron's personal account.
- **Why:** Reviewers look at the person. The repo sits on Ron's profile next to his commits and can be transferred to an organization later with redirects.
- **Ron:**

### D-003 · 2026-11-21 · Unit status as a Postgres view owned by Rails
- **Decision:** Derived unit status and board KPIs live in one Postgres view (`unit_status_today`), created by a Rails migration. Phoenix reads it and never re-implements the rules.
- **Options considered:** a Rails query object with Phoenix duplicating the rules; a Postgres view read by both apps.
- **Why:** One definition of the status rules for both apps (SPEC §5).
- **Ron:**

### D-005 · 2026-11-21 · Parallel agents, split by app boundary
- **Decision:** After the skeleton, CI and a contract PR are merged, two agents work in separate git worktrees. Agent A owns `apps/admin` (schema, view, constraints, role, seed, models, admin, rent roll, NOTIFY). Agent B owns `apps/board` and `studio/`. Neither touches the other's paths. `docs/CONTRACT.md` fixes the view columns, status values, KPI columns and the NOTIFY channel and payload; changing it is a stop-and-ask item.
- **Options considered:** one agent working serially; splitting database work from application work; splitting by app.
- **Why:** Splitting database from application would put two agents in the same Rails app (models, migrations, structure.sql). Splitting by app matches the architecture's own boundary, and the contract keeps the status rules in one place.
- **Ron:**

### D-006 · 2026-11-21 · Integration branch with agent auto-merge; Ron approves main
- **Decision:** Agents work as `leaseboard-bot`, open PRs into `dev`, and use GitHub auto-merge (CI must be green). The bot opens `dev → main` PRs; a ruleset requires Ron's approving review. Feature → dev: rebase-merge. dev → main: merge commit.
- **Options considered:** Ron merges every PR (Ron becomes the bottleneck); agents merge to main (no human gate); dev branch under Ron's identity (gate not enforceable).
- **Why:** Keeps agents moving while Ron is away, and enforces the human gate in GitHub rather than in agent instructions.
- **Ron:**

### D-004 · 2026-11-21 · mise + `.tool-versions` as the single version source
- **Decision:** A root `.tool-versions` pins Ruby, Erlang, Elixir and Node. mise installs from it in the devcontainer. CI reads the same file through `ruby/setup-ruby`, `erlef/setup-beam` (`version-file: .tool-versions`, `version-type: strict`) and `actions/setup-node` (`node-version-file: .tool-versions`). Postgres is pinned by image tag in `.devcontainer/compose.yml` and in the CI service.
- **Options considered:** versions hard-coded separately in the Dockerfile and in each CI job; devcontainer features per language (no Elixir/Erlang feature is published by the devcontainers org); asdf; mise with `mise.toml`.
- **Why:** One file, read natively by mise and by the standard setup actions, so the devcontainer and CI can't drift. `.tool-versions` rather than `mise.toml` because all three setup actions read it. Elixir is pinned without an `-otp-NN` suffix because setup-beam documents only plain Elixir versions as input.
- **Ron:**

## Versions (pin at setup)
Checked 2026-11-21 against official release pages. Library versions (Rails, Phoenix, LiveView, Sanity) are the current releases. Lock files pin them when the apps are generated.

| Tool | Version | Source |
|---|---|---|
| Ruby | 4.0.10 | ruby-lang.org/en/downloads |
| Rails | 8.1.4.1 (requires Ruby >= 3.2.0) | rubygems.org/gems/rails |
| Erlang/OTP | 29.1.2 | erlang.org/downloads |
| Elixir | 1.20.5 (supports OTP 27-29) | elixir-lang.org/install, Elixir compatibility table |
| Phoenix / LiveView | 1.8.17 (requires Elixir ~> 1.15) / 1.2.15 | hex.pm |
| Node | 26.13.1 (Active LTS) | nodejs.org, github.com/nodejs/release |
| Postgres | 18 (image `postgres:18.7`) | render.com/docs/postgresql-upgrading: Render offers 13-18, not 19 |
| Sanity | 6.24.0 | registry.npmjs.org/sanity/latest |
| Dev container base | `mcr.microsoft.com/devcontainers/base:3.0.14-ubuntu24.04` | mcr.microsoft.com tag list |
