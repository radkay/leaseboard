# Approach

Leaseboard shows evidence of using parallel agent work streams to build, test, and deploy
robust, production-quality applications in stacks the human hadn't shipped before (Rails,
Elixir/Phoenix, Sanity), while keeping a human in the loop for oversight and
decision-making. The app is the vehicle; the exhibit is the process: the decisions, the
reviews, and the guardrails that make agent work trustworthy. This page summarizes how it
works, and every claim links to the entry that records it.

## What "done" means
Speed to market was not the only goal. Code quality, avoiding bloat, and efficient
processing were treated as deliverables in their own right:
- **Quality:** every change passes tests, RuboCop, Brakeman, Credo and `mix format` in CI
  before it can merge, and corrections are recorded honestly in the review log.
- **No bloat:** dependencies are added only when the platform's own tools fall short, and
  each one needs approval. The board's charts are server-rendered SVG rather than a chart
  library (D-015), while CSV uses Ruby's own `csv` gem rather than hand-rolled code (R-011).
- **Efficiency:** N+1 queries fail the tests, the rent roll runs as a single query, status
  rules run once in Postgres (D-013), and the board updates through LISTEN/NOTIFY rather
  than polling.

## The agent loop
Each task runs the same rhythm (CLAUDE.md "Working rhythm"): restate the goal, **post a
time estimate before the first command** so its timestamp is honest, write the tests,
implement, run tests, lint and security locally, open one PR per task into `dev`, and enable
auto-merge. Estimates are kept honest by review: a retroactive estimate was caught twice
([R-007](REVIEW-LOG.md), [R-008](REVIEW-LOG.md)), which is why they're now posted up front.

## Layered guardrails
No single mechanism is trusted; they stack, strongest on the server:
1. **Instructions:** CLAUDE.md's "stop and ask" list and hard rules.
2. **Deny rules:** committed `.claude/settings.json` denies force-push, secret files, and
   edits to its own rules; gaps here were themselves review findings
   ([R-002](REVIEW-LOG.md), [R-003](REVIEW-LOG.md)).
3. **Auto-mode classifier:** blocks the agent from merging its own PRs; it stopped a
   self-merge even when the branch had no required checks, which is what surfaced the need
   for a required CI gate.
4. **GitHub rulesets:** the server-side backstop that enforces what instructions can't:
   force-push and direct pushes to `main` are blocked, and `dev → main` requires Ron's
   review ([D-006](DECISIONS.md)).

**Platform-native controls.** The rules that matter most are enforced by GitHub itself, not
by instructions an agent could ignore. Branch rulesets require a pull request for every
change, block force pushes and deletions, and require my approval for anything entering
`main`. A required `ci-ok` status check means nothing reaches `dev` without green CI, and
GitHub's native auto-merge lets agents merge into `dev` only once that check passes. Agents
work under a separate `leaseboard-bot` account, so GitHub, not trust, guarantees that an
agent can never approve its own way into `main`. Issues serve as the agents' work orders,
and pull request descriptions carry their proposed log entries. Agent-side deny rules and
Claude Code's own permission checks are a first layer; GitHub is the backstop (D-006, R-002,
R-003).

## Review and oversight
Agents built the code; review happened in layers. CI and the guardrails checked every
change automatically. A separate review assistant, an independent AI session with no write
access to the repository, checked agent plans and pull requests against the spec and
CLAUDE.md, and raised concerns. I made every decision and approved every merge into `main`.
Corrections from any of these layers are recorded in REVIEW-LOG.md, including the time the
review assistant's own proposed fix proved impossible and an agent caught it (R-015).

## Branches, checkpoints and parallel agents
Agents work as `leaseboard-bot`, branch from `origin/dev`, and auto-merge into `dev` once
the single `ci-ok` check is green ([D-006](DECISIONS.md), [D-009](DECISIONS.md)). Work is
split by app boundary so two agents run in parallel without colliding: Agent A owns
`apps/admin`, Agent B owns `apps/board` and `studio/` ([D-005](DECISIONS.md)). A written
**contract** (`docs/CONTRACT.md`) fixes the read interface between them, the view columns,
status values, KPI definitions and the NOTIFY channel, so neither re-implements the other's
rules ([D-003](DECISIONS.md), [D-010](DECISIONS.md), [D-012](DECISIONS.md)). Changing it is
a stop-and-ask item.

## The log process
The decision and review logs are the exhibit, so they can't be a source of merge conflicts.
Feature PRs **propose** entries in their descriptions; the `dev → main` checkpoint PR writes
them all to the files, numbered in order, in one commit ([D-011](DECISIONS.md)). This also
gives Ron one place to review every entry.

## Platform-first choices
The design leans on the database and the platform rather than extra services, "boring
technology" (SPEC §2):
- **Postgres views/functions as the single source of truth for status.** Derived unit
  status and the board KPIs live in Rails-owned Postgres objects; Phoenix reads them and
  never re-derives the rules ([D-003](DECISIONS.md)). The per-unit derivation is one SQL
  function used by both the live "today" view and the arbitrary-date rent roll, so there's
  exactly one definition ([D-013](DECISIONS.md)).
- **LISTEN/NOTIFY instead of Redis.** Lease writes emit `NOTIFY lease_changed` after commit;
  Phoenix listens via `Postgrex.Notifications` and fans out over PubSub. The live board
  needs no Redis or polling (`docs/CONTRACT.md` §6).
- **Server-rendered SVG instead of a chart library.** The board renders its KPI and
  occupancy visuals as SVG from the server, avoiding a client-side charting dependency
  ([D-015](DECISIONS.md)).

## Scope notes
This is a weekend build, so some production practices are deliberately out of scope. A true
production setup would add a staging environment: `dev` deployed automatically to staging
for verification, and `main` promoted to production only after it passes there. Here, the
`dev` branch and the checkpoint PRs into `main` play that role.
