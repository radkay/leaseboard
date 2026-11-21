# Review Log

What Ron caught when reviewing agent-written code. This is the project's most important exhibit:
it shows the judgment behind the agents. Log every correction honestly. Newest at the bottom.

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

### R-010 · 2026-11-21 · CI cancelled runs on dev, so a merge went untested
- **Where:** `.github/workflows/ci.yml` (`concurrency`)
- **Agent produced:** `cancel-in-progress: true` for every event, grouped by branch.
- **Problem:** correctness. Merging #8 and #9 back to back pushed to `dev` twice; the second run cancelled the first, so the Phoenix job never finished on `dev`. Because each push run only tests its own changes, nothing re-tested it.
- **Fix:** In-progress runs are cancelled only for pull requests; pushes to `dev` and `main` always run to completion.
- **Caught by:** Ron's review (first merges into `dev`)
