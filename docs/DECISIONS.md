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
- **Ron:** Approved; no quote recorded.

### D-003 · 2026-11-21 · Unit status as a Postgres view owned by Rails
- **Decision:** Derived unit status and board KPIs live in one Postgres view (`unit_status_today`), created by a Rails migration. Phoenix reads it and never re-implements the rules.
- **Options considered:** a Rails query object with Phoenix duplicating the rules; a Postgres view read by both apps.
- **Why:** One definition of the status rules for both apps (SPEC §5).
- **Ron:** Approved; no quote recorded.

### D-005 · 2026-11-21 · Parallel agents, split by app boundary
- **Decision:** After the skeleton, CI and a contract PR are merged, two agents work in separate git worktrees. Agent A owns `apps/admin` (schema, view, constraints, role, seed, models, admin, rent roll, NOTIFY). Agent B owns `apps/board` and `studio/`. Neither touches the other's paths. `docs/CONTRACT.md` fixes the view columns, status values, KPI columns and the NOTIFY channel and payload; changing it is a stop-and-ask item.
- **Options considered:** one agent working serially; splitting database work from application work; splitting by app.
- **Why:** Splitting database from application would put two agents in the same Rails app (models, migrations, structure.sql). Splitting by app matches the architecture's own boundary, and the contract keeps the status rules in one place.
- **Ron:** Approved; no quote recorded.

### D-006 · 2026-11-21 · Integration branch with agent auto-merge; Ron approves main
- **Decision:** Agents work as `leaseboard-bot`, open PRs into `dev`, and use GitHub auto-merge (CI must be green). The bot opens `dev → main` PRs; a ruleset requires Ron's approving review. Feature → dev: rebase-merge. dev → main: merge commit.
- **Options considered:** Ron merges every PR (Ron becomes the bottleneck); agents merge to main (no human gate); dev branch under Ron's identity (gate not enforceable).
- **Why:** Keeps agents moving while Ron is away, and enforces the human gate in GitHub rather than in agent instructions.
- **Ron:** Approved; no quote recorded.

### D-004 · 2026-11-21 · mise + `.tool-versions` as the single version source
- **Decision:** A root `.tool-versions` pins Ruby, Erlang, Elixir and Node. mise installs from it in the devcontainer. CI reads the same file through `ruby/setup-ruby`, `erlef/setup-beam` (`version-file: .tool-versions`, `version-type: strict`) and `actions/setup-node` (`node-version-file: .tool-versions`). Postgres is pinned by image tag in `.devcontainer/compose.yml` and in the CI service.
- **Options considered:** versions hard-coded separately in the Dockerfile and in each CI job; devcontainer features per language (no Elixir/Erlang feature is published by the devcontainers org); asdf; mise with `mise.toml`.
- **Why:** One file, read natively by mise and by the standard setup actions, so the devcontainer and CI can't drift. `.tool-versions` rather than `mise.toml` because all three setup actions read it. Elixir is pinned without an `-otp-NN` suffix because setup-beam documents only plain Elixir versions as input.
- **Ron:** Approved; no quote recorded.

### D-007 · 2026-11-21 · Supported ways to open the devcontainer
- **Decision:** Open the devcontainer with "Clone Repository in Container Volume" or GitHub Codespaces. When opening a local folder ("Reopen in Container") instead, the repo must sit alone in its own parent folder. The compose file mounts the repo's parent at `/workspaces` (`../..:/workspaces:cached`).
- **Options considered:** (a) the template mount `../..:/workspaces`, which works for container volumes, Codespaces and local folders, but mounts a local folder's whole parent directory; (b) `..:/workspaces/leaseboard`, which mounts only the repo for a local folder but hides the clone under container volumes (R-004).
- **Why:** (a) is the form used by the official devcontainers Compose templates and recommended by the VS Code maintainers for container volumes (microsoft/vscode-remote-release#5388). Its one risk, exposing sibling folders on the host to the container, is avoided by the two recommended setups, and by the "alone in its own parent folder" rule for local folders.
- **Ron:** Approved; no quote recorded.

### D-008 · 2026-11-21 · Rails skeleton: one Postgres, no Solid*, SQL schema format
- **Decision:** Generate `apps/admin` with `rails new --database=postgresql --skip-kamal --skip-ci --skip-solid` and set `config.active_record.schema_format = :sql`. One Postgres database; no Solid Cache/Queue/Cable; the schema is dumped as `db/structure.sql`, not `schema.rb`.
- **Options considered:** keep the Rails 8 defaults (Solid Cache/Queue/Cable on SQLite side databases, `schema.rb`); drop Solid* and use `:sql`.
- **Why:** The architecture is one shared Postgres that Phoenix reads (SPEC §4); the Solid* adapters add extra databases and migrations this app doesn't need. The derived-status Postgres **view** (`unit_status_today`, D-003) and the read-only `board_reader` role can't be represented in `schema.rb`, so `:sql` is the only format that dumps them faithfully. `--skip-ci` and `--skip-kamal` because CI is one monorepo workflow (task 4) and deploys go to Render, not Kamal.
- **Ron:** Approved; no quote recorded.

### D-009 · 2026-11-21 · CI shape: one workflow, path-filtered app jobs, a single `ci-ok` gate
- **Decision:** One `.github/workflows/ci.yml` with a job per app (Rails, Phoenix, Sanity), each guarded by a path filter so it runs only when its directory changed. A `changes` job detects the touched paths with plain `git diff` (no third-party action), and a single always-running `ci-ok` job aggregates the results — green only if every app job passed or was skipped. `ci-ok` is the one check the `dev` ruleset will require.
- **Options considered:** separate workflow files per app; `dorny/paths-filter` (or similar) for path detection; making each app job itself a required check in the ruleset.
- **Why:** A monorepo touches one app at a time far more often than all three, so path filters keep CI fast and the signal relevant. Native `git diff` avoids adding an action outside the pre-approved set (`ruby/setup-ruby`, `erlef/setup-beam`, `actions/setup-node`), so no dependency approval is needed. A single `ci-ok` gate means the ruleset needs exactly one required check whose name never changes as apps come and go, and "passed or skipped" lets an unrelated PR go green without running every app. Versions still come from the one root `.tool-versions` (D-004).
- **Ron:** Approved; no quote recorded.

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
- **Ron:** Approved; no quote recorded.

### D-014 · 2026-11-22 · Estimates give both human time and agent time
- **Decision:** Every task estimate gives two numbers — human time (what a senior engineer would take) and agent time (what the agent expects to take) — and the actual (agent wall-clock) is recorded against both.
- **Options considered:** a single estimate (the process until now, which R-007/R-008 showed was ambiguous about whose time it was); two estimates (human + agent).
- **Why:** A single number conflated the human baseline with the agent's pace. Two estimates keep the human reference (how long this would take a senior — useful for the exhibit) separate from the agent's prediction, and the actual shows the speed-up honestly.
- **Ron:** "Take a note that estimates are human time. Moving forward, we should provide two estimates. Human and agent time."

### D-015 · 2026-11-22 · Server-rendered SVG components instead of a chart library
- **Decision:** Build the board's charts as plain Phoenix function components rendering SVG and CSS, with no chart library and no JS hooks.
- **Options considered:** a JS charting library via a hook (rejected — adds JS, a dependency, and can't be asserted server-side); the Contex Elixir library (held in reserve); hand-built SVG function components (chosen).
- **Why:** It uses LiveView's own rendering and diffing, so charts update live with the page for free, add no JavaScript, and are testable end-to-end with LiveViewTest (assert the rendered values). The hand-built expirations chart was straightforward, so Contex wasn't needed; if axes/labels later get awkward, adding Contex would be proposed as a needs-ron item.
- **Ron:** Approved; no quote recorded.

### D-016 · 2026-11-22 · The board CI job re-runs when the Rails schema/views change
- **Decision:** A change to `apps/admin/db/structure.sql` triggers the board job in CI, even when `apps/board` is unchanged.
- **Options considered:** per-app path filter only (board runs only on `apps/board` changes); treat `structure.sql` as a fully shared input (runs all apps); trigger just the board job on it (chosen).
- **Why:** The board reads the Rails-owned views via `board_reader`; a schema/view change can break those reads, so the board tests must re-run. Studio doesn't read the database, so it's left out.
- **Ron:** Approved; no quote recorded.

### D-017 · 2026-11-22 · APPROACH.md revised by Ron; agent-draft marker removed
- **Decision:** Ron revised APPROACH.md (new lead, "What 'done' means", "Review and oversight", "Platform-native controls", "Scope notes"), removed every em dash, and removed the agent-draft marker.
- **Options considered:** leave the agent draft as-is; Ron revises it (chosen).
- **Why:** APPROACH.md is the reviewer-facing summary, so it should be in Ron's words, not an agent draft.
- **Ron:** Approved; no quote recorded.

### D-018 · 2026-11-22 · Production cache store is `:memory_store`
- **Decision:** Use Rails' in-process `:memory_store` as the cache in all environments, not Solid Cache or Redis.
- **Options considered:** Solid Cache (the Rails 8 default); Redis / `mem_cache_store`; `:null_store`; `:memory_store` (chosen).
- **Why:** Solid Cache was skipped at setup (D-008) and the app avoids Redis (it leans on Postgres LISTEN/NOTIFY, not a cache server). The only cached thing is non-critical, 5-minute, safe-to-recompute Sanity listing content, so a per-instance in-memory cache suffices for the single-instance demo; a multi-instance deployment would switch to a shared store. Test moved from `:null_store` to `:memory_store` so the caching test is meaningful.
- **Ron:** Approved; no quote recorded.

### D-019 · 2026-11-22 · Keep the transport seam instead of adding a mocking gem
- **Decision:** Minitest 6 dropped `Minitest::Mock`; rather than add `minitest-mock` (or Mocha), the Sanity tests use a transport seam (a swappable callable) to exercise the client with no network and no mocking gem.
- **Options considered:** add `minitest-mock`; add Mocha; a dependency-free transport seam (chosen).
- **Why:** The one network boundary is small and already injectable, so a seam avoids a new test dependency and keeps the suite's style consistent. Broader mocking later would be a needs-ron item.
- **Ron:** "Keep the test seam."

### D-020 · 2026-11-22 · The board ships with no migrate entrypoint
- **Decision:** Remove the generated Ecto migrate release task from the board; a read-only service ships no migrate entrypoint.
- **Options considered:** keep the generated (unused) migrate task; remove it (chosen).
- **Why:** The board never owns schema or writes (Rails is the only writer; CONTRACT.md), so a migrate entrypoint is dead code and a wrong signal. It can be restored if ever needed.
- **Ron:** "Agree with no migrate entrypoint."

### D-021 · 2026-11-22 · Decision rights in three tiers; PR template; contract-name CI guard
- **Decision:** Replace the flat "stop and ask" list with Tier 1 (Ron decides) / Tier 2 (decide and disclose, including accepted defaults) / Tier 3 (decide), add a PR template that requires disclosing those decisions, and define all databases/roles/targets only in CONTRACT.md's Environments table, enforced (plus "the board owns no migrations") by a stdlib-Ruby CI guard.
- **Options considered:** keep the flat list; tiers without enforcement; tiers plus an automated guard (chosen).
- **Why:** The #58 audit showed names drifting from framework defaults with nothing to catch it; tiers clarify who decides, and the guard makes "names live in one place" checkable in CI.
- **Ron:** "Add the tiers and template to Phase 3."

### D-022 · 2026-11-22 · Single database per environment; roles and grants out of migrations
- **Decision:** One database per environment owned by a non-superuser Rails role; Phoenix reads as a per-environment reader role. A psql bootstrap (run as `postgres`) creates the database and both roles; one privileges SQL file grants the reader and locks down the SECURITY DEFINER function, applied after every database build via `Rake::Task#enhance`. Migrations never create roles or grant.
- **Options considered:** keep role creation + grants in migrations (what #58 found: framework defaults, superuser everywhere); move them to a bootstrap + privileges script owned outside migrations (chosen).
- **Why:** #58 showed two drifted databases and the board connecting as superuser everywhere but prod. Separating who creates databases and roles (`postgres`, once) from what the app does (own its data; read-only reader) gives least privilege, one source for grants, and an owner that never needs superuser.
- **Ron:** "The go forward decision will be with one database within the development environment."

### D-023 · 2026-11-22 · Environment naming scheme
- **Decision:** The environments are `leaseboard_dev` / `leaseboard_test` / `leaseboard_prod`, owned by `admin_dev` / `admin_test` / `admin_prod` and read by `reader_dev` / `reader_test` / `reader_prod`; the superuser `postgres` is used only to create databases and roles. The names live only in CONTRACT.md's Environments table.
- **Options considered:** keep the framework-default names (`admin_development`, `board_dev`); one deliberate scheme named in one place (chosen).
- **Why:** The audit (#58) found names invented by generators, unmanaged. One scheme, defined once, makes the names reviewable and keeps a role out of any other environment's database.
- **Ron:** "If the issue is admin in production, we could go with admin_prod, too."

### D-024 · 2026-11-22 · Rebuild the environments fresh rather than migrate an existing database
- **Decision:** Build the per-environment databases from scratch (bootstrap plus schema load / migrate), discarding the old `admin_development` / `board_dev`, rather than migrating or renaming them in place.
- **Options considered:** migrate / rename the existing databases in place; drop and rebuild fresh (chosen).
- **Why:** Production had never been migrated, and the local databases carried drifted data and framework-default ownership. A fresh build gives a clean, reproducible baseline that matches the migrations exactly (verified by regenerating `structure.sql`).
- **Ron:** Approved; no quote recorded.

### D-025 · 2026-11-22 · Foreign keys are deferrable so the non-superuser test owner can load fixtures
- **Decision:** Define the three foreign keys `DEFERRABLE INITIALLY DEFERRED` (Rails' `foreign_key: { deferrable: :deferred }`), and set `verify_foreign_keys_for_fixtures = false` in test. FK violations are checked at transaction commit, not per statement.
- **Options considered:** keep immediate FKs and make `admin_test` a superuser in test so Rails can disable referential integrity and run its pg_constraint FK verification; deferrable FKs plus turning the fixture FK-verification off (chosen).
- **Why:** The owner is deliberately not a superuser (D-022). Rails loads fixtures by disabling referential integrity and verifying FKs via `pg_constraint`, both superuser-only. Deferrable FKs let fixtures insert in any order with integrity still enforced at commit for real writes, so no part of the stack needs superuser. No test relies on immediate FK failure.
- **Ron:** Approved; no quote recorded.

### D-026 · 2026-11-22 · Paid Render plans for the demo period
- **Decision:** Run `leaseboard_prod` on `0.1c-256mb` and both web services on `0.5c-512mb` (Render's current ids for the former Basic-256mb / Starter), billed per second.
- **Options considered:** the free tier; paid plans for the demo period (chosen).
- **Why:** A paid web plan is required for the admin's `preDeployCommand` (migrations plus privileges), which the free plan does not run; the paid database tier persists, where the free database expires after about 30 days. Downgrade or delete after the job search.
- **Ron:** "I'm good with the paid plan."

### D-027 · 2026-11-22 · MIT license
- **Decision:** License the project under the MIT License, Copyright (c) 2026 Ron Radkay, with a one-line mention in the README.
- **Options considered:** no license; a permissive license (MIT, chosen).
- **Why:** A public exhibit repository should state its terms, and MIT is permissive and standard.
- **Ron:** "Add MIT."

### D-028 · 2026-11-22 · Editorial-restraint design direction, tokens in one source
- **Decision:** One token set (warm off-white, near-black, mid-gray, one deep-green accent, a muted colorblind-safe five-status palette, system fonts, 8px spacing, 2px max radius, thin rules not boxes), defined once in docs/DESIGN.md with measured WCAG-AA ratios and mirrored per app (admin and listing as Propshaft CSS custom properties; the board as a daisyUI theme).
- **Options considered:** a CSS framework; per-app ad hoc styles; one shared token file consumed natively by each app (chosen).
- **Why:** Restraint and one source keep the three surfaces consistent without a framework dependency, and recorded contrast ratios make accessibility checkable.
- **Ron:** "Go with editorial restraint."

### D-029 · 2026-11-22 · Admin navigation: units and leases from the property page and the rent roll
- **Decision:** Units and leases are reachable from the property page and the rent roll. The admin uses tables, not scaffold cards. "Add new lease" is an in-page floating panel (a native `<dialog>` opened with `show()`, the form in a Turbo Frame, success/error via Turbo Stream), reusing `Leases::SignNewLease` so the business rules and the board's live update are unchanged. The Destroy actions and routes are removed, with a test that keeps them out.
- **Options considered:** keep the generated card/show navigation and a separate new-lease page; tables with in-page panel navigation and no delete (chosen).
- **Why:** The admin is a proof of concept for operators; tables and in-page actions read faster than scaffold cards and page hops, and a POC has no need for a delete flow.
- **Ron:** "Remove destroy button. This is a POC."

### D-030 · 2026-11-22 · A recorded exception to D-011
- **Decision:** The REVIEW-LOG highlights for #81 were written before a checkpoint, as a one-time recorded exception to D-011. The log entries themselves were not changed.
- **Options considered:** hold to D-011 (write only at the checkpoint); a recorded exception (chosen).
- **Why:** The highlights were needed before the checkpoint; recording the exception keeps the log process honest rather than silently departing from D-011.
- **Ron:** Approved; no quote recorded.

### D-031 · 2026-11-23 · Admin navigation: scaffold list pages removed
- **Decision:** The scaffold list pages for units, leases and residents were removed. Navigation runs through properties and the rent roll, and each record's back link points to its parent (unit → property, lease → unit; residents keep no back link).
- **Options considered:** keep the scaffold index pages; remove them and route navigation through properties and the rent roll (chosen).
- **Why:** Nothing in the UI linked to those index pages, so they were dead ends; properties and the rent roll are the real entry points, and parent back links match how operators move through the data.
- **Ron:** "Approved."

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
