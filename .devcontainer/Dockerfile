FROM mcr.microsoft.com/devcontainers/base:3.0.14-ubuntu24.04

# Build dependencies for Ruby (ruby-build) and Erlang (kerl fallback if no
# precompiled build), libpq for the pg gem, inotify-tools for Phoenix live reload.
# The PGDG repository provides postgresql-client-18 to match the server major:
# pg_dump refuses to dump a newer server, and Rails writes db/structure.sql with it.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        autoconf \
        build-essential \
        inotify-tools \
        libffi-dev \
        libgmp-dev \
        libncurses-dev \
        libpq-dev \
        libreadline-dev \
        libssl-dev \
        libyaml-dev \
        postgresql-common \
        zlib1g-dev \
    && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
    && apt-get install -y --no-install-recommends postgresql-client-18 \
    && rm -rf /var/lib/apt/lists/*

# mise, pinned, from its official image (mise.jdx.dev/mise-cookbook/docker.html).
COPY --from=ghcr.io/jdx/mise:2026.11.12 /usr/local/bin/mise /usr/local/bin/mise

# mise shims on PATH so login, non-login and VS Code task shells all use the
# versions pinned in .tool-versions.
ENV PATH="/home/vscode/.local/share/mise/shims:${PATH}"
