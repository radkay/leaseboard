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

### D-007 · 2026-11-21 · Supported ways to open the devcontainer
- **Decision:** Open the devcontainer with "Clone Repository in Container Volume" or GitHub Codespaces. When opening a local folder ("Reopen in Container") instead, the repo must sit alone in its own parent folder. The compose file mounts the repo's parent at `/workspaces` (`../..:/workspaces:cached`).
- **Options considered:** (a) the template mount `../..:/workspaces`, which works for container volumes, Codespaces and local folders, but mounts a local folder's whole parent directory; (b) `..:/workspaces/leaseboard`, which mounts only the repo for a local folder but hides the clone under container volumes (R-004).
- **Why:** (a) is the form used by the official devcontainers Compose templates and recommended by the VS Code maintainers for container volumes (microsoft/vscode-remote-release#5388). Its one risk, exposing sibling folders on the host to the container, is avoided by the two recommended setups, and by the "alone in its own parent folder" rule for local folders.
- **Ron:**

### D-008 · 2026-11-21 · Rails skeleton: one Postgres, no Solid*, SQL schema format
- **Decision:** Generate `apps/admin` with `rails new --database=postgresql --skip-kamal --skip-ci --skip-solid` and set `config.active_record.schema_format = :sql`. One Postgres database; no Solid Cache/Queue/Cable; the schema is dumped as `db/structure.sql`, not `schema.rb`.
- **Options considered:** keep the Rails 8 defaults (Solid Cache/Queue/Cable on SQLite side databases, `schema.rb`); drop Solid* and use `:sql`.
- **Why:** The architecture is one shared Postgres that Phoenix reads (SPEC §4); the Solid* adapters add extra databases and migrations this app doesn't need. The derived-status Postgres **view** (`unit_status_today`, D-003) and the read-only `board_reader` role can't be represented in `schema.rb`, so `:sql` is the only format that dumps them faithfully. `--skip-ci` and `--skip-kamal` because CI is one monorepo workflow (task 4) and deploys go to Render, not Kamal.
- **Ron:**

### D-009 · 2026-11-21 · CI shape: one workflow, path-filtered app jobs, a single `ci-ok` gate
- **Decision:** One `.github/workflows/ci.yml` with a job per app (Rails, Phoenix, Sanity), each guarded by a path filter so it runs only when its directory changed. A `changes` job detects the touched paths with plain `git diff` (no third-party action), and a single always-running `ci-ok` job aggregates the results — green only if every app job passed or was skipped. `ci-ok` is the one check the `dev` ruleset will require.
- **Options considered:** separate workflow files per app; `dorny/paths-filter` (or similar) for path detection; making each app job itself a required check in the ruleset.
- **Why:** A monorepo touches one app at a time far more often than all three, so path filters keep CI fast and the signal relevant. Native `git diff` avoids adding an action outside the pre-approved set (`ruby/setup-ruby`, `erlef/setup-beam`, `actions/setup-node`), so no dependency approval is needed. A single `ci-ok` gate means the ruleset needs exactly one required check whose name never changes as apps come and go, and "passed or skipped" lets an unrelated PR go green without running every app. Versions still come from the one root `.tool-versions` (D-004).
- **Ron:**

### D-010 · 2026-11-21 · Board KPI definitions confirmed
- **Decision:** The three KPIs in `property_kpis_today` are: `occupancy_pct = 100 * (occupied + on_notice + on_notice_rented) / total_units`; `leased_pct = 100 * (occupied + on_notice_rented + vacant_rented) / total_units`; `available_units = vacant_available + on_notice`. CONTRACT.md §3.1 is updated to match and is now authoritative.
- **Options considered:** the two readings SPEC §5's informal wording left open — whether "on notice" includes `on_notice_rented`, and how to read leased %'s "minus on_notice" (both set out in CONTRACT.md §3.1 before this confirmation).
- **Why:** SPEC §5 stated the KPIs ambiguously, and the board (Agent B) needs one authoritative definition to read. Ron confirmed the physically-occupied reading for occupancy, the committed-lease reading for leased, and approved the `property_kpis_today` view.
- **Ron:** "KPI definitions confirmed. 1. Occupancy % counts every physically occupied unit (occupied, on_notice, on_notice_rented.) 2. Leased % counts units with a current or signed future lease (occupied, on_notice_rented, vacant_rented;) units on notice with no new lease don't count. 3. Available units = vacant_available + on_notice. Approve the property_kpis_today view."

### D-011 · 2026-11-21 · Log entries proposed in PRs, written at checkpoints
- **Decision:** Feature PRs propose D-### and R-### entries in their descriptions. The checkpoint PR into `main` writes all proposed entries to DECISIONS.md and REVIEW-LOG.md, numbered in order, in one commit.
- **Options considered:** every PR edits the log files directly (the process until now); one log file per entry; proposals in PRs, written at checkpoints.
- **Why:** Every PR appended to the end of the same two files, so concurrent PRs conflicted. This happened twice with one agent (#7, #11). Adding a second agent (D-005) would make it constant. Writing the logs at checkpoints removes the conflicts and gives Ron one place to review all entries.
- **Ron:** "Changing how we keep the decision and review logs, before we bring in a second agent. Two PRs (#7, #11) already conflicted in DECISIONS.md because every PR appends to the end of the same file. With two agents working in parallel, that becomes constant rework. From now on, PRs propose log entries in their descriptions, and the checkpoint PR into main writes them to the log files in order, in one commit."

### D-012 · 2026-11-22 · Contract adds unit-type KPIs, a 12-month expirations view, and lease fields on the status view
- **Decision:** CONTRACT.md gains `property_unit_type_kpis_today` (the D-010 KPIs per property × bedroom count) and `lease_expirations_12m` (a 12-month expirations series per property, split renewed/relet vs open); `unit_status_today` gains `bedrooms`, `market_rent`, the current lease's rent/end/notice/move-out dates, and the next signed lease's start date. No board-read view exposes resident names.
- **Options considered:** keep the two original views only; add just the expirations view; add unit-type granularity and expirations together (chosen).
- **Why:** Ron asked for occupancy broken out by unit type and a view of upcoming expirations, and for the status view to carry enough per-unit lease detail for the board's unit cards without re-deriving anything or exposing resident PII.
- **Ron:** "Let's include 3 and 5. While we're at it, it would be great if we have some unit type granularity, like, units with 0 (studio,) 1, 2, 3 bedrooms. Then we could show occupancy within the unit type."

### D-013 · 2026-11-22 · One SQL function for the status rules, used by both the board view and the rent roll
- **Decision:** Extract the per-unit status derivation into `unit_status_as_of(date)`; `unit_status_today` wraps it at `CURRENT_DATE` and the admin rent roll calls it for an arbitrary date. The function is `SECURITY DEFINER` so the read-only `board_reader` keeps working through the views.
- **Options considered:** duplicate the rules in a separate rent-roll query; a second view per date (not possible — a view can't take a parameter); one shared function (chosen).
- **Why:** CLAUDE.md requires the status rules to live in one place. A parameterised function is the one construct both the fixed "today" view and the arbitrary-date rent roll can share.
- **Ron:**

### D-014 · 2026-11-22 · Estimates give both human time and agent time
- **Decision:** Every task estimate gives two numbers — human time (what a senior engineer would take) and agent time (what the agent expects to take) — and the actual (agent wall-clock) is recorded against both.
- **Options considered:** a single estimate (the process until now, which R-007/R-008 showed was ambiguous about whose time it was); two estimates (human + agent).
- **Why:** A single number conflated the human baseline with the agent's pace. Two estimates keep the human reference (how long this would take a senior — useful for the exhibit) separate from the agent's prediction, and the actual shows the speed-up honestly.
- **Ron:** "Take a note that estimates are human time. Moving forward, we should provide two estimates. Human and agent time."

### D-015 · 2026-11-22 · Server-rendered SVG components instead of a chart library
- **Decision:** Build the board's charts as plain Phoenix function components rendering SVG and CSS, with no chart library and no JS hooks.
- **Options considered:** a JS charting library via a hook (rejected — adds JS, a dependency, and can't be asserted server-side); the Contex Elixir library (held in reserve); hand-built SVG function components (chosen).
- **Why:** It uses LiveView's own rendering and diffing, so charts update live with the page for free, add no JavaScript, and are testable end-to-end with LiveViewTest (assert the rendered values). The hand-built expirations chart was straightforward, so Contex wasn't needed; if axes/labels later get awkward, adding Contex would be proposed as a needs-ron item.
- **Ron:**

### D-016 · 2026-11-22 · The board CI job re-runs when the Rails schema/views change
- **Decision:** A change to `apps/admin/db/structure.sql` triggers the board job in CI, even when `apps/board` is unchanged.
- **Options considered:** per-app path filter only (board runs only on `apps/board` changes); treat `structure.sql` as a fully shared input (runs all apps); trigger just the board job on it (chosen).
- **Why:** The board reads the Rails-owned views via `board_reader`; a schema/view change can break those reads, so the board tests must re-run. Studio doesn't read the database, so it's left out.
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
