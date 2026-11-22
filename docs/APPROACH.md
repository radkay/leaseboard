# Approach

> **Agent draft.** Written by the agent from `DECISIONS.md`, `REVIEW-LOG.md` and the PR
> history, for Ron to revise in his own words before the checkpoint.

Leaseboard is a test of whether an AI agent, directed and reviewed by a human, can ship
production-quality code in stacks the human hasn't shipped before (Rails, Elixir/Phoenix,
Sanity). The app is the vehicle; the exhibit is the **process** — the decisions, the
reviews, and the guardrails that make agent work trustworthy. This page summarizes how it
works. Every claim links to the entry that records it.

## The agent loop
Each task runs the same rhythm (CLAUDE.md "Working rhythm"): restate the goal, **post a
time estimate before the first command** so its timestamp is honest, write the tests,
implement, run tests + lint + security locally, open one PR per task into `dev`, and enable
auto-merge. Estimates are kept honest by review: a retroactive estimate was caught twice
([R-007](REVIEW-LOG.md), [R-008](REVIEW-LOG.md)), which is why they're now posted up front.

## Layered guardrails
No single mechanism is trusted; they stack, strongest on the server:
1. **Instructions** — CLAUDE.md's "stop and ask" list and hard rules.
2. **Deny rules** — committed `.claude/settings.json` denies force-push, secret files, and
   edits to its own rules; gaps here were themselves review findings
   ([R-002](REVIEW-LOG.md), [R-003](REVIEW-LOG.md)).
3. **Auto-mode classifier** — blocks the agent from merging its own PRs; it stopped a
   self-merge even when the branch had no required checks, which is what surfaced the need
   for a required CI gate.
4. **GitHub rulesets** — the server-side backstop that enforces what instructions can't:
   force-push and direct pushes to `main` are blocked, and `dev → main` requires Ron's
   review ([D-006](DECISIONS.md)).

## Branches, checkpoints and parallel agents
Agents work as `leaseboard-bot`, branch from `origin/dev`, and auto-merge into `dev` once
the single `ci-ok` check is green ([D-006](DECISIONS.md), [D-009](DECISIONS.md)). Work is
split by app boundary so two agents run in parallel without colliding — Agent A owns
`apps/admin`, Agent B owns `apps/board` and `studio/` ([D-005](DECISIONS.md)). A written
**contract** (`docs/CONTRACT.md`) fixes the read interface between them — view columns,
status values, KPI definitions and the NOTIFY channel — so neither re-implements the
other's rules ([D-003](DECISIONS.md), [D-010](DECISIONS.md), [D-012](DECISIONS.md)).
Changing it is a stop-and-ask item.

## The log process
The decision and review logs are the exhibit, so they can't be a source of merge conflicts.
Feature PRs **propose** entries in their descriptions; the `dev → main` checkpoint PR writes
them all to the files, numbered in order, in one commit ([D-011](DECISIONS.md)). This also
gives Ron one place to review every entry.

## Platform-first choices
The design leans on the database and the platform rather than extra services — "boring
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
  occupancy visuals as SVG from the server, avoiding a client-side charting dependency.
  _(Agent B / `apps/board`; the decision entry lands with that work.)_
