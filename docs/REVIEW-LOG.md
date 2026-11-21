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
