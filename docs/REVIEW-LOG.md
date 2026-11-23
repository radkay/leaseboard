# Review Log

What Ron caught when reviewing agent-written code. This is the project's most important exhibit:
it shows the judgment behind the agents. Log every correction honestly. Newest at the bottom.

## Highlights

A few corrections that show the judgment behind the agents. Each links its full entry below;
the entries themselves are unchanged.

- **A SECURITY DEFINER function callable by any role.** The shared status function ran with its
  owner's rights but left EXECUTE to PUBLIC, so any role could call it directly. We revoked
  EXECUTE from PUBLIC, granted only the board reader, and made the function return a lease id
  rather than resident data, so a direct call leaks nothing
  ([R-012](#r-012--2026-11-22--a-security-definer-function-callable-by-any-role)).
- **The review assistant's own fixes were sometimes wrong, and the agent checked.** Its proposed
  lockdown (revoke all EXECUTE) would have broken the board's views, and its suggested advisory
  lock could not cover a role race that is cluster-wide. Both times the agent verified the
  behavior in Postgres and escalated instead of guessing
  ([R-015](#r-015--2026-11-22--proposed-fix-revoke-all-execute-was-impossible-in-postgres),
  [R-016](#r-016--2026-11-22--a-test-setup-creating-a-cluster-wide-role-raced-under-parallel-tests)).
- **Defaults are not decisions.** Each framework's generator default was accepted, and
  development quietly ran on two databases with the board connected as the superuser. I treated
  it as a decision-rights failure, fixed the rule rather than just the config, and paused the
  deploy until it was right
  ([R-020](#r-020--2026-11-22--development-ran-on-two-databases)).
- **Agents cannot rewrite their own rules.** Even under an approved work order, the auto-mode
  classifier blocked an agent from committing a change to CLAUDE.md; it stopped and asked, and I
  reviewed and committed it
  ([R-021](#r-021--2026-11-22--an-agent-couldnt-commit-changes-to-its-own-rules)).
- **Credit where it is due.** The metrics write-up had credited me with catches the review
  assistant made; we corrected the attribution from the log's own "Caught by" lines
  ([R-023](#r-023--2026-11-22--the-metrics-section-credited-ron-with-the-review-assistants-catches)).

CI and the guardrails stop the mechanical mistakes before merge, so what is logged here is the
judgment and design: the calls caught by reading the work.

## Template
### R-### · YYYY-MM-DD · Short title
- **Where:** file / module
- **Agent produced:** what the code did
- **Problem:** idiom | performance | correctness | security | maintainability, plus a one-line why
- **Fix:** what changed
- **Caught by:** Ron's review | test | CI | lint

---

### R-001 · 2026-11-21 · Agent attributed an unmade decision to Ron
- **Where:** Saturday AM plan (planning output, before any code)
- **Agent produced:** A plan stating "Ron's D-001 picks the Dev Container" and promising to quote "Ron's words" in each decision entry. Ron had not made D-001; the handoff notes only suggested options.
- **Problem:** correctness / process. A decision log that credits the human with calls he didn't make is worse than no log, because the record can't be trusted.
- **Fix:** Ron reviewed the options (WSL2, Dev Container, native Windows) and made the call himself (D-001). CLAUDE.md now requires that any "Ron:" quote be verbatim from Ron in the current session, or left blank.
- **Caught by:** Ron's review

### R-002 · 2026-11-21 · Guardrail deny list had gaps, including self-editing
- **Where:** `.claude/settings.json`
- **Agent produced:** A deny list covering force-push, pushes to main, hard reset, `rm -rf`, the GitHub, Render and Sanity CLIs, and `.env` files, for both Bash and PowerShell.
- **Problem:** security. The agent could edit `.claude/settings.json` and remove its own rules; `git clean`, PowerShell delete aliases and remote branch deletion were not covered; `config/master.key` was readable.
- **Fix:** Denied edits to `.claude/**`, added the missing delete, branch-deletion and secret-file rules, and documented the two cases a deny list cannot express, which the GitHub rulesets enforce on the server instead.
- **Caught by:** Ron's review

### R-003 · 2026-11-21 · A "don't ask again" approval allowed every git command
- **Where:** `.claude/settings.local.json` (local, uncommitted permissions)
- **Agent produced:** Not agent code. Approving a git prompt with "don't ask again" saved the rule `PowerShell(git *)`, which allowed every git command without asking, including force-push and `git reset --hard`. The file was ignored only by a machine-level global git ignore, not by the repo's .gitignore, so a fresh clone (the devcontainer or a reviewer's Codespace) would not ignore it.
- **Problem:** security / process. One convenience click widened the agent's permissions far beyond the read-only commands intended, before any deny rules existed to limit it.
- **Fix:** Stop-gap: narrowed the local allow list to read-only git commands and git-ignored the file. Lasting fix: the committed deny rules in `.claude/settings.json` override any local allow, and the GitHub rulesets block force-push and direct pushes to `main` on GitHub's side.
- **Caught by:** Ron's review (independent review session)

### R-004 · 2026-11-21 · Workspace mount hid the cloned repo; toolchain never installed
- **Where:** `.devcontainer/compose.yml`
- **Agent produced:** A bind mount `..:/workspaces/leaseboard`, and a PR statement that "Clone Repository in Container Volume" works with it. Docker wasn't installed yet, so this was untested.
- **Problem:** correctness. With a container volume, `..` is resolved on Docker's host, not in the volume, so an empty directory was mounted over the cloned repo. mise found no `.tool-versions`, so Ruby, Erlang and Elixir were never installed, and Node fell back to the Claude Code feature's v18.
- **Fix:** Changed the app service's mount to `../..:/workspaces:cached` (the repo's parent at `/workspaces`, with `workspaceFolder` unchanged at `/workspaces/leaseboard`), matching the official devcontainers Compose templates and the maintainer-recommended form for Clone in Container Volume in microsoft/vscode-remote-release#5388.
- **Caught by:** Ron's review (first container build; the risk was flagged when compose.yml was reviewed)

### R-005 · 2026-11-21 · Devcontainer shipped without `gh`, which the working rhythm depends on
- **Where:** `.devcontainer/devcontainer.json`
- **Agent produced:** A devcontainer with the Claude Code feature but no GitHub CLI, even though CLAUDE.md's working rhythm runs every task through `gh` (open the PR, enable auto-merge, record the actual time) and the bot signs in as leaseboard-bot via `gh auth`.
- **Problem:** correctness / completeness. The prescribed workflow couldn't be executed in a fresh container; `gh` had to be installed by hand before the first PR could be opened.
- **Fix:** Added the official `ghcr.io/devcontainers/features/github-cli:1` feature (pinned to major 1) and committed `.devcontainer/devcontainer-lock.json` pinning it to the resolved digest, so every rebuild gets the same `gh`.
- **Caught by:** Ron's review (first use of the container)

### R-006 · 2026-11-21 · Claude config volume owned by root, so the login couldn't be saved
- **Where:** `.devcontainer/Dockerfile`
- **Agent produced:** A named volume mounted at `/home/vscode/.claude` to persist Claude Code's login, but no matching directory in the image. Docker created the empty volume's mount point owned by root, so Claude Code (running as `vscode`) couldn't write to it and the login didn't persist.
- **Problem:** correctness. A named volume inherits the ownership of the image directory it mounts over; with no such directory, Docker defaults it to root, which the non-root `vscode` user can't write.
- **Fix:** Create `/home/vscode/.claude` owned by `vscode` in the Dockerfile (`install -d -o vscode -g vscode`), so a fresh volume inherits that ownership. Per Docker's volumes docs, "Populate a volume using a container" — an empty named volume is seeded from the image's mount-point directory, ownership included. Stop-gap before the fix was a manual `chown`.
- **Caught by:** Ron's review (first use of the container)

### R-007 · 2026-11-21 · Estimate and time reported after the fact
- **Where:** PR description for fix/devcontainer-gh-cli
- **Agent produced:** An "Estimate ~45 min / Actual ~40 min" section, although no estimate was written before the task, and the session had run about 15–20 minutes.
- **Problem:** correctness / process. A retroactive estimate isn't an estimate, and an inflated actual undermines the estimation record the working rhythm exists to build.
- **Fix:** Reported the estimate as not recorded and the actual from the session's start and end times. From the next PR on, the estimate is written in the PR before work starts.
- **Caught by:** Ron's review

### R-008 · 2026-11-21 · Retroactive estimate repeated after R-007
- **Where:** PR #7 description (task 1, Rails skeleton)
- **Agent produced:** "Estimate: ~25 min / Actual: ~25 min" while noting that work began before an estimate was written. The task ran about 5 minutes (20:33–20:38 UTC).
- **Problem:** correctness / process. The same failure as R-007, one PR after the fix promised it would stop: an estimate written after the fact, and an actual that matched it instead of the clock.
- **Fix:** Estimate reported as not recorded and actual taken from timestamps. From task 2 on, the estimate is posted as a comment on the PR, or on #6, before the first command of the task, so its timestamp proves when it was written.
- **Caught by:** Ron's review

### R-009 · 2026-11-21 · CI didn't re-test apps when shared files changed
- **Where:** `.github/workflows/ci.yml` (`changes` job path filter)
- **Agent produced:** Per-app path filters that run a job only when its own directory (`apps/admin`, `apps/board`, `studio`) changed. A change to a file every app depends on — `.tool-versions`, the workflow itself, or the devcontainer — matched no app filter, so a version bump or CI edit could merge with no app re-tested.
- **Problem:** correctness. The path filter was too narrow: shared inputs affect all apps but triggered none, leaving those changes unverified.
- **Fix:** The `changes` job treats `.tool-versions`, `.github/workflows/**` and `.devcontainer/**` as shared — a change to any of them runs all three app jobs.
- **Caught by:** Ron's review

### R-010 · 2026-11-21 · CI cancelled runs on dev, so a merge went untested
- **Where:** `.github/workflows/ci.yml` (`concurrency`)
- **Agent produced:** `cancel-in-progress: true` for every event, grouped by branch.
- **Problem:** correctness. Merging #8 and #9 back to back pushed to `dev` twice; the second run cancelled the first, so the Phoenix job never finished on `dev`. Because each push run only tests its own changes, nothing re-tested it.
- **Fix:** In-progress runs are cancelled only for pull requests; pushes to `dev` and `main` always run to completion.
- **Caught by:** Ron's review (first merges into `dev`)

### R-011 · 2026-11-22 · Hand-rolled CSV instead of the platform's library
- **Where:** `app/models/rent_roll.rb` (`RentRoll#to_csv`)
- **Agent produced:** A small hand-written CSV writer, because the `csv` library is no longer a default gem in Ruby 4.0 and adding a dependency is a stop-and-ask item.
- **Problem:** maintainability / security. Re-implementing CSV quoting invites subtle bugs, and the hand-rolled version had no spreadsheet formula-injection hardening; the platform library is battle-tested.
- **Fix:** Ron approved the `csv` gem; `to_csv` uses `CSV.generate`, and cells starting with `=`, `+`, `-` or `@` are neutralized, with a test.
- **Caught by:** Ron's review

### R-012 · 2026-11-22 · A SECURITY DEFINER function callable by any role
- **Where:** `unit_status_as_of` (status function)
- **Agent produced:** The shared status function was SECURITY DEFINER with EXECUTE left to PUBLIC, so any role could call it directly with the owner's rights and read a resident id from its output.
- **Problem:** security. A definer function callable by everyone is a privilege/data-leak surface.
- **Fix:** `REVOKE EXECUTE FROM PUBLIC`; grant only `board_reader` (which must keep EXECUTE to read the views — R-015); the function returns the current lease **id**, not resident data, so a direct call exposes nothing personal. Fitness test proves PUBLIC can't execute it and its output has no resident column.
- **Caught by:** Ron's review

### R-013 · 2026-11-22 · faker in the wrong gem group for the production seed
- **Where:** `apps/admin/Gemfile`
- **Agent produced:** faker was added to the `development, test` group, but `bin/rails db:seed` populates the live demo on Render, which installs gems without those groups — so the seed would fail in production.
- **Problem:** correctness. A gem a production task needs must be in the default group.
- **Fix:** Moved faker to the default group (still used only by the seed).
- **Caught by:** Ron's review

### R-014 · 2026-11-22 · A view recreate dropped board_reader's grants
- **Where:** task 8's status-function migration
- **Agent produced:** Task 8 dropped and recreated `unit_status_today` and the two KPI views; dropping a view drops its grants, so `board_reader` silently lost SELECT on all three — the board couldn't read them in dev/production.
- **Problem:** correctness. A view recreate must re-apply the reader's grants.
- **Fix:** Extracted `BoardReaderRole.grant_reads!` and call it from every view-recreating migration; re-granted `board_reader`. (The fitness test had masked this because it provisions the role itself.)
- **Caught by:** Agent A (self-caught while implementing R-012)

### R-015 · 2026-11-22 · Proposed fix (revoke all execute) was impossible in Postgres
- **Where:** the `unit_status_as_of` lockdown (R-012)
- **Agent produced:** The review proposed revoking EXECUTE so `board_reader` couldn't call the function while still reading the views.
- **Problem:** correctness. Postgres checks a function's EXECUTE against the invoking role even when the function is called through a view, so a view's readers need EXECUTE on functions the view calls; revoking it from `board_reader` breaks the views.
- **Fix:** The agent verified this in Postgres and escalated instead of guessing; Ron chose to keep one function, grant only `board_reader`, and return a lease id so a direct call leaks nothing.
- **Caught by:** Agent A (verified in Postgres)

### R-016 · 2026-11-22 · A test setup creating a cluster-wide role raced under parallel tests
- **Where:** `lib/board_reader_role.rb` (`install!` / `create_or_update_role!`)
- **Agent produced:** `install!` created `board_reader` with a check-then-create. Postgres roles are cluster-wide, but the suite runs in 4 parallel processes (each in its own database), so two could both pass the existence check and CREATE (a duplicate key on `pg_authid`) and, once it exists, concurrently ALTER it (`tuple concurrently updated`). It passed on PRs by chance and failed on main.
- **Problem:** correctness / concurrency. The check-then-create isn't atomic, and the contention is cross-database. The review's suggested advisory lock wouldn't work: advisory locks are per-database, and roles are cluster-wide.
- **Fix:** Retry the create-or-update on the transient `duplicate key` / `tuple concurrently updated` errors (the DO block also swallows a concurrent-CREATE duplicate), with a test that races role creation from two connections. The retry was later removed when roles moved out of migrations entirely (D-022).
- **Caught by:** CI on main

### R-017 · 2026-11-22 · The free-tier deploy plan would not have worked
- **Where:** `render.yaml` / the deploy plan
- **Agent produced:** A Render Blueprint on the free tier for the database and both web services.
- **Problem:** correctness. Render's pre-deploy command (migrations + privileges) and shell need a paid plan, and a custom build command replaces Render's default `bundle install`. On the free tier the pre-deploy would not run at all.
- **Fix:** A build script (`bin/render-build.sh`) that runs `bundle install` itself (#57), and the paid-plan decision (D-026).
- **Caught by:** the review assistant, before any deploy

### R-018 · 2026-11-22 · The listing controller queried a view directly, and Sanity fallbacks left no trace
- **Where:** `ListingsController`, the availability count and the Sanity client
- **Agent produced:** The controller derived the available-unit count by querying a status view directly, and Sanity failures fell back to placeholder copy with no log line.
- **Problem:** maintainability. Business logic belongs in a model, not the controller, and a silent fallback hides a Sanity outage.
- **Fix:** Moved the count to `Property#available_units`, and logged every Sanity fallback (#57).
- **Caught by:** the review assistant

### R-019 · 2026-11-22 · The guardrails held unattended
- **Where:** `.claude/settings.json` deny rules
- **Agent produced:** Overnight, an agent attempted a force-push and a remote branch deletion.
- **Problem:** security. Both are destructive and outside the agreed workflow; the test was whether the deny rules hold with no human watching.
- **Fix:** Both were blocked by the committed deny rules and the agent asked instead of working around them. No change needed; recorded as evidence the guardrails work unattended.
- **Caught by:** the deny-rule guardrails

### R-020 · 2026-11-22 · Development ran on two databases
- **Where:** `apps/admin/config/database.yml`, `apps/board/config/dev.exs`, `apps/board/config/test.exs`, `.devcontainer/compose.yml`, CI
- **Agent produced:** each framework's generator default was accepted. Rails used `admin_development`, Phoenix used `board_dev`, and the board connected as the superuser everywhere except production.
- **Problem:** development and test didn't match the production design (one database, a read-only board). It went unnoticed for about 16 hours, from the Phoenix skeleton on Saturday afternoon through the overnight run. It was found in Ron's Sunday-morning pre-deploy review: the review assistant noted the demo script forcing both apps onto one database, Ron asked why, and the answer exposed the split. Ron treated it as a decision-rights failure rather than a config bug, and paused the deploy.
- **Fix:** a read-only audit (#58); an Environments table in CONTRACT.md as the only place databases and roles are named; decision tiers and a PR template that require disclosing every accepted default (#61); and one database per environment with per-environment roles, built fresh (#62 to #70).
- **Caught by:** the review assistant, in Ron's Sunday-morning pre-deploy review
- **Ron:** "I realized I wasn't descriptive enough in the decisions. Nothing defined the environments, so the agents filled the gaps with defaults. We fixed the rule, not just the config, and paused the deploy until it was right."

### R-021 · 2026-11-22 · An agent couldn't commit changes to its own rules
- **Where:** `CLAUDE.md` / `.claude/`
- **Agent produced:** Under an approved work order (#59), the agent edited CLAUDE.md's decision tiers and tried to commit the change.
- **Problem:** security / self-modification. An agent editing and committing its own rules is exactly what the guardrails exist to stop, even under an approved task.
- **Fix:** The auto-mode classifier blocked the commit; the agent stopped and asked, and Ron reviewed and committed it. CLAUDE.md and `.claude/` are now Tier 1.
- **Caught by:** the auto-mode classifier

### R-022 · 2026-11-22 · A dangerous runbook fallback in DEPLOY.md
- **Where:** `docs/DEPLOY.md`
- **Agent produced:** The runbook offered creating `reader_prod` from Render's dashboard, and asserted a Render permission without a citation.
- **Problem:** security / correctness. A user added through the dashboard becomes the database's default user, which would repoint the admin's `DATABASE_URL` at the read-only role and break writes; and an uncited platform claim does not belong in a runbook.
- **Fix:** Create `reader_prod` only with SQL as `admin_prod`, never from the dashboard, and stop and ask if `CREATE ROLE` is refused rather than assume the permission (#69).
- **Caught by:** the review assistant

### R-023 · 2026-11-22 · The metrics section credited Ron with the review assistant's catches
- **Where:** `docs/APPROACH.md` (agent-loop metrics)
- **Agent produced:** The metrics section attributed most REVIEW-LOG corrections to Ron's own review and claimed the review assistant caught none, and framed the estimate-versus-actual gap as a measured speedup.
- **Problem:** correctness. The review assistant surfaced most corrections, with Ron deciding; and the senior-engineer figure is an estimate, not a measured time, so the gap is indicative, not a measured speedup.
- **Fix:** Attribute from the log's "Caught by" lines, credit the review assistant, and state the estimate framing; #62's estimate matched its actual, so it is not an undershoot (metrics-fix PR).
- **Caught by:** the review assistant

### R-024 · 2026-11-22 · Questions for Ron merged without the needs-ron label
- **Where:** process (PRs #62, #67)
- **Agent produced:** #62 and #67 carried questions for Ron but no `needs-ron` label, and #67 auto-merged.
- **Problem:** process. A PR with an open question for Ron should carry `needs-ron` and not auto-merge, so the question is not lost at merge.
- **Fix:** Process reminder issued: any PR with a "Questions for Ron" section gets `needs-ron` and does not auto-merge.
- **Caught by:** Ron's review

### R-025 · 2026-11-22 · The Sanity import runbook was never run
- **Where:** `docs/DEPLOY.md` (the Sanity import step) and the listing NDJSON
- **Agent produced:** The import runbook used a non-existent `--dry-run` flag and the wrong token variable, and the NDJSON asset references lacked the `file://` scheme the importer requires.
- **Problem:** correctness; platform behavior was asserted without checking Sanity's docs (CLAUDE.md rule).
- **Fix:** #85, #83; import verified in production at 17:07.
- **Caught by:** Ron's production run

### R-026 · 2026-11-22 · "Placeholder copy — replace before launch." shipped on the public listings
- **Where:** the public listing pages (Sanity listing content), which the README links to
- **Agent produced:** "Placeholder copy — replace before launch." was published on the public listing pages that the README links to.
- **Problem:** correctness, public-facing.
- **Fix:** #87, re-imported 17:29.
- **Caught by:** the review assistant

### R-027 · 2026-11-22 · README claims a reviewer could check were false
- **Where:** `README.md` (draft)
- **Agent produced:** The README draft claimed branch rules require a reviewed PR for every change (false for dev, D-010) and that logs are written "as it happens" (contradicts D-011).
- **Problem:** correctness; a public claim a reviewer can check.
- **Fix:** #83.
- **Caught by:** the review assistant
