-- The single source of the reader role's grants and the status-function lockdown
-- (CONTRACT.md: "grants and the function lockdown come from one privileges script,
-- never from migrations"). Run as the database owner (Rails' role). Idempotent.
--
-- Applied automatically after every database build — db:migrate, schema load and
-- test preparation — by lib/tasks/privileges.rake, which runs it through
-- ActiveRecord (so no psql client is needed at deploy time). It is also a valid
-- psql script:
--
--   psql -v db=leaseboard_dev -v owner=admin_dev -v reader=reader_dev \
--     -f apps/admin/db/privileges.sql
--
-- Parameters (all identifiers): :db, :owner, :reader

-- Reset the reader on this schema, then grant exactly what the contract allows.
REVOKE ALL ON SCHEMA public FROM :reader;
GRANT USAGE ON SCHEMA public TO :reader;

-- The four board-read views plus properties (for names). No base tables, so no
-- resident PII ever reaches the board.
GRANT SELECT ON
  unit_status_today,
  property_kpis_today,
  property_unit_type_kpis_today,
  lease_expirations_12m,
  properties
TO :reader;

-- unit_status_as_of is SECURITY DEFINER: lock PUBLIC out so no role can call it
-- with the owner's rights, and grant only the reader, which must keep EXECUTE to
-- read the views that call it (R-015).
REVOKE EXECUTE ON FUNCTION unit_status_as_of(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION unit_status_as_of(date) TO :reader;

-- Limit CONNECT on this database to this environment's own roles, so a role from
-- another environment cannot reach it.
REVOKE CONNECT ON DATABASE :db FROM PUBLIC;
GRANT CONNECT ON DATABASE :db TO :owner;
GRANT CONNECT ON DATABASE :db TO :reader;
