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

# render.yaml names its managed database (and, once set, its databaseName/user)
# in the top-level `databases:` block. Scan only that block so the service
# `name:` entries (leaseboard-admin, leaseboard-board) aren't mistaken for
# database/role names. Render resource names may contain hyphens.
RENDER_YAML = "render.yaml"
RENDER_PATTERNS = [
  /^\s*-?\s*name:\s*([a-z][a-z0-9_-]*)/,
  /^\s*-?\s*databaseName:\s*([a-z][a-z0-9_-]*)/,
  /^\s*-?\s*user:\s*([a-z][a-z0-9_-]*)/
].freeze

# Legacy names still in config until the single-database migration finishes.
# This set is a TEMPORARY shim: it lets names that predate the migration stay
# green while the rename lands across PRs. Adding to it is a Tier 1 change
# (needs Ron). #59 Task 2 (Rails) and #60 (the board) must empty it, and this
# whole PENDING_MIGRATION mechanism is deleted once it is empty.
PENDING_MIGRATION = {
  "leaseboard"        => "container superuser → postgres (board config + CI board job, #60)",
  "board_dev"         => "apps/board/config/dev.exs → reader_dev/leaseboard_dev (#60)",
  "board_test"        => "apps/board/config/test.exs → reader_test/leaseboard_test (#60)",
  "leaseboard-db"     => "render.yaml managed-database resource name (reconciled at deploy)"
}.freeze

def scan(path, patterns, allowed, violations)
  return unless File.exist?(File.join(ROOT, path))

  text = File.read(File.join(ROOT, path))
  patterns.each do |pattern|
    text.scan(pattern).flatten.each do |name|
      next if allowed.include?(name) || PENDING_MIGRATION.key?(name)

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
        next if allowed.include?(name) || PENDING_MIGRATION.key?(name)

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
  pending = PENDING_MIGRATION.empty? ? "" : " (#{PENDING_MIGRATION.size} name(s) still pending migration)"
  puts "contract guard: OK#{pending}"
  exit 0
end

warn "contract guard: FAILED"
violations.each { |v| warn "  - #{v}" }
warn "\nEvery database/role must be named in docs/CONTRACT.md's Environments table."
warn "PENDING_MIGRATION is a temporary shim for names that predate the single-database"
warn "migration; adding to it is a Tier 1 change (needs Ron). #59 Task 2 and #60 must"
warn "empty it, after which this whole mechanism is deleted."
exit 1
