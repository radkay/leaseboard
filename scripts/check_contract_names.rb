#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Contract guard (CLAUDE.md hard rules + CONTRACT.md Environments table).
#
# Fails if:
#   1. an app config file names a database or role that is not in
#      docs/CONTRACT.md's Environments table, or
#   2. apps/board/priv/repo/migrations contains any migration (the board never
#      owns schema; Rails is the only writer).
#
# Stdlib only, so both CI and the dev container can run it with the system Ruby:
#   ruby scripts/check_contract_names.rb

require "set"

ROOT = File.expand_path("..", __dir__)

# The allowed names are exactly the backticked tokens in the Environments table
# (databases, owner roles, reader roles, and the `postgres` bootstrap user).
def contract_names
  contract = File.read(File.join(ROOT, "docs/CONTRACT.md"))
  section = contract[/^## Environments$.*?(?=^## )/m] ||
            abort("guard: '## Environments' table not found in docs/CONTRACT.md")
  section.scan(/`([a-z][a-z0-9_]*)`/).flatten.to_set
end

# Each site is a config file plus regexes whose first capture is a database or
# role/connection-user name to validate. Scanning named declaration sites (not
# whole files) keeps the guard precise and free of false positives.
SITES = {
  "apps/admin/config/database.yml" => [
    /^\s*database:\s*([a-z][a-z0-9_]*)/,
    /^\s*username:\s*([a-z][a-z0-9_]*)/
  ],
  "apps/board/config/dev.exs" => [
    /database:\s*"([a-z][a-z0-9_]*)/,
    /get_env\("POSTGRES_USER",\s*"([a-z][a-z0-9_]*)"\)/
  ],
  "apps/board/config/test.exs" => [
    /database:\s*"([a-z][a-z0-9_]*)/,
    /get_env\("POSTGRES_USER",\s*"([a-z][a-z0-9_]*)"\)/
  ],
  ".env.example" => [
    /^POSTGRES_USER=([a-z][a-z0-9_]*)/
  ],
  ".devcontainer/compose.yml" => [
    /POSTGRES_USER:\s*([a-z][a-z0-9_]*)/,
    /POSTGRES_USER=([a-z][a-z0-9_]*)/
  ],
  ".github/workflows/ci.yml" => [
    /POSTGRES_USER:\s*([a-z][a-z0-9_]*)/,
    %r{postgres://([a-z][a-z0-9_]*):}
  ]
}.freeze

# render.yaml: validate only the managed database's `databaseName` and `user`, in
# the top-level `databases:` block. The resource `name:` entries are Render labels
# (e.g. leaseboard-db, leaseboard-admin), not database or role names, so they are
# not checked.
RENDER_YAML = "render.yaml"
RENDER_PATTERNS = [
  /^\s*-?\s*databaseName:\s*([a-z][a-z0-9_]*)/,
  /^\s*-?\s*user:\s*([a-z][a-z0-9_]*)/
].freeze

def scan(path, patterns, allowed, violations)
  return unless File.exist?(File.join(ROOT, path))

  text = File.read(File.join(ROOT, path))
  patterns.each do |pattern|
    text.scan(pattern).flatten.each do |name|
      next if allowed.include?(name)

      violations << "#{path}: '#{name}' is not in CONTRACT.md's Environments table"
    end
  end
end

def check_config_names(allowed)
  violations = []
  SITES.each { |path, patterns| scan(path, patterns, allowed, violations) }

  # render.yaml: scan only the `databases:` block (up to the next top-level key).
  render_path = File.join(ROOT, RENDER_YAML)
  if File.exist?(render_path)
    block = File.read(render_path)[/^databases:\n.*?(?=^\S)/m].to_s
    RENDER_PATTERNS.each do |pattern|
      block.scan(pattern).flatten.each do |name|
        next if allowed.include?(name)

        violations << "#{RENDER_YAML}: '#{name}' is not in CONTRACT.md's Environments table"
      end
    end
  end

  violations
end

def check_board_has_no_migrations
  dir = File.join(ROOT, "apps/board/priv/repo/migrations")
  return [] unless Dir.exist?(dir)

  stray = Dir.children(dir).reject { |f| f == ".formatter.exs" }.sort
  stray.map do |f|
    "apps/board/priv/repo/migrations/#{f}: the board must not own migrations (Rails is the only writer)"
  end
end

allowed = contract_names
violations = check_config_names(allowed) + check_board_has_no_migrations

if violations.empty?
  puts "contract guard: OK"
  exit 0
end

warn "contract guard: FAILED"
violations.each { |v| warn "  - #{v}" }
warn "\nEvery database/role must be named in docs/CONTRACT.md's Environments table."
exit 1
