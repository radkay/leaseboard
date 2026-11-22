# CLAUDE.md - Leaseboard

You are building Leaseboard with Ron Radkay. Ron directs and reviews; you write the code.
Read `docs/SPEC.md` first. It is the source of truth for scope. Status and private context are kept outside this repo; ask Ron if you need them.

## The point of this project
Show that agent-built code in Rails, Elixir/Phoenix and Sanity can meet a senior reviewer's bar.
Write the code an experienced Rails or Elixir engineer would write, not merely code that passes tests.
When there is an idiomatic way, use it. When you are unsure of the idiom, say so and explain the options.

## Stop and ask Ron before you
- Add any dependency (gem, hex package, npm package)
- Create or change a migration, a database role or a Postgres view
- Deploy, or change anything in Render, Sanity project settings or GitHub settings
- Touch secrets or environment variables
- Change or cut scope in SPEC.md, or deviate from the architecture
- Delete files or rewrite git history

Everything else (code, tests, docs inside the agreed scope) you may do without asking. Show the diff and test results.

## Hard rules
- **Never attribute a decision or quote to Ron** unless he stated it verbatim in the current session. Otherwise leave "Ron:" blank for him to fill in.
- **Synthetic data only.** Never use or reproduce code, data, client names or schemas from any employer or client.
- **Rails is the only writer.** Phoenix connects as `board_reader` (SELECT only) and must never write.
- **Status rules live in one place** (the Rails-owned view/query). Phoenix reads them and never re-implements them.
- **No secrets in the repo.** Use `.env` locally (git-ignored) and Render env vars in production.
- **Work in small steps.** One concern per commit. Tests and lint pass before every commit.

## Rails conventions (apps/admin)
- Follow Rails defaults (the Rails way); RuboCop `rails-omakase` style.
- Business logic lives in models or small plain-Ruby objects, not controllers and not callback chains.
  Use `after_commit` only for side effects like the NOTIFY.
- Prevent N+1: `includes`/`preload` on index pages; `strict_loading` or Bullet must fail tests on N+1.
- Hotwire (Turbo + Stimulus) for interactivity; no React/SPA in admin.
- Minitest + fixtures or factories (ask before adding factory_bot). Brakeman clean.

## Elixir/Phoenix conventions (apps/board)
- Use Phoenix contexts (e.g. `Board.Occupancy`). LiveViews stay thin.
- Don't add a GenServer unless state or a process is genuinely needed. The Postgrex.Notifications
  listener is supervised. Let it crash and restart; no defensive try/rescue around it.
- Ecto schemas map the view/tables read-only. No changesets for writes.
- PubSub topic per property: `"property:<id>"`.
- `mix format`, Credo (strict), and ExUnit including LiveView tests.

## Sanity (studio/)
- TypeScript schema. GROQ queries live in one Rails module with a timeout and a fallback.

## Logs you must keep (these are the exhibit)
Every decision and every correction earns an entry. Entries are **proposed in the PR that
earns them** (in a "Log entries" section — see Working rhythm); the files below are written
only by the checkpoint PR into `main`, which adds all proposed entries numbered in order, in
one commit. Feature PRs do not edit these files, so concurrent PRs never conflict in them.
1. **docs/DECISIONS.md.** One entry per decision: `D-###`, date, decision, options considered,
   why, and Ron's words when he made the call. Tool and framework versions were pinned here at setup.
2. **docs/REVIEW-LOG.md.** When Ron rejects or corrects your code: `R-###`, date, file,
   what you produced, what was wrong (idiom, performance, correctness, security), and the fix.
   Record it honestly, including your own mistakes. This log is the most important artifact.

## CI (GitHub Actions)
- admin: `bin/rails test`, RuboCop, Brakeman, with a Postgres service.
- board: `mix deps.get`, `mix format --check-formatted`, `mix credo --strict`, `mix test`, with Postgres.
- studio: typecheck/build.
- CI must be green before any merge to `main`.

## Working rhythm
For each task: restate the goal in one line → write **two estimates** in the PR → write the
tests → implement → run tests and lint → push a feature branch → open a PR into `dev` → enable
auto-merge (`gh pr merge --auto --rebase`) → record the actual time in the PR.
- **Two estimates, every time.** Give **human time** (what a senior engineer would take) and
  **agent time** (what you expect to take). Record the actual (agent wall-clock) against both,
  so the record shows the human baseline, the agent's prediction, and what it actually took
  (D-014).
- Stop-and-ask items that Ron has not pre-approved: label the PR `needs-ron`, do not enable
  auto-merge, put the question under a "Questions for Ron" heading, and continue with work that
  does not depend on it.
- Only Ron merges into `main`. `dev → main` PRs use a merge commit.
- Propose D-### and R-### entries in a "Log entries" section of the PR description; do **not**
  edit DECISIONS.md or REVIEW-LOG.md in a feature PR. The checkpoint PR into `main` writes all
  proposed entries to the log files, numbered in order, in one commit, with "Ron:" left blank
  unless he said it verbatim.
