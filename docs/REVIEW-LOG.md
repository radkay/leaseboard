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
