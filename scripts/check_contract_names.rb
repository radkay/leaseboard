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
#
# The single-database migration lands across several PRs (Rails first, then the
# board), so names not yet renamed live in PENDING_MIGRATION below, each tagged
# with the PR that removes it. The guard is fully strict once that set is empty.

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
  ".github/workflows/ci.yml" => [
    /POSTGRES_USER:\s*([a-z][a-z0-9_]*)/,
    %r{postgres://([a-z][a-z0-9_]*):}
  ]
}.freeze

# Legacy names still in config until the single-database migration finishes.
# Remove each as its PR lands; when this is empty the guard is fully strict.
PENDING_MIGRATION = {
  "leaseboard"        => "container superuser → postgres (board config + CI board job, Agent B)",
  "board_dev"         => "apps/board/config/dev.exs → reader_dev/leaseboard_dev (Agent B)",
  "board_test"        => "apps/board/config/test.exs → reader_test/leaseboard_test (Agent B)",
  "admin_development" => "apps/admin/config/database.yml → leaseboard_dev (db/single-database)"
}.freeze

def check_config_names(allowed)
  violations = []
  SITES.each do |relpath, patterns|
    path = File.join(ROOT, relpath)
    next unless File.exist?(path)

    text = File.read(path)
    patterns.each do |pattern|
      text.scan(pattern).flatten.each do |name|
        next if allowed.include?(name) || PENDING_MIGRATION.key?(name)

        violations << "#{relpath}: '#{name}' is not in CONTRACT.md's Environments table"
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
warn "\nDefine every database/role in docs/CONTRACT.md's Environments table, or"
warn "add a transitional entry to PENDING_MIGRATION in scripts/check_contract_names.rb."
exit 1
