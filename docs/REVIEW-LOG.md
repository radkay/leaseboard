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
