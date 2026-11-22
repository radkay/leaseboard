# Leaseboard

A small property-operations app built agent-first: a **Rails** admin, a **Phoenix LiveView** live
occupancy board and **Sanity** listing content on one Postgres database, hosted on Render.

Built by Ron Radkay directing AI coding agents. Decisions are in [docs/DECISIONS.md](docs/DECISIONS.md),
and what review caught is in [docs/REVIEW-LOG.md](docs/REVIEW-LOG.md).

> Status: spec complete, build starting. See [docs/SPEC.md](docs/SPEC.md).

All data is synthetic.

## Development setup

The toolchain runs in a dev container (`.devcontainer/`). Open it one of two ways:

- **VS Code:** run "Dev Containers: Clone Repository in Container Volume" with this repo's URL.
- **GitHub Codespaces:** Code → Codespaces → Create codespace.

If you open a local folder instead ("Reopen in Container"), the repo must sit alone in its own
parent folder. The container mounts the repo's parent directory at `/workspaces`, so any other
repositories or files beside it would be visible inside the container. See D-007 in
[docs/DECISIONS.md](docs/DECISIONS.md).

## License

Licensed under the [MIT License](LICENSE).
