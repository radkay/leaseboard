-- Bootstrap one environment's database and its two roles. Run as the cluster
-- superuser (postgres); never by an application. Idempotent.
--
-- psql variables (all required), supplied by db/bootstrap:
--   db, owner, owner_password, reader, reader_password
--
--   psql -v ON_ERROR_STOP=1 \
--     -v db=leaseboard_dev -v owner=admin_dev -v owner_password=... \
--     -v reader=reader_dev -v reader_password=... -f db/bootstrap.sql
--
-- Role names are identifiers, passwords are literals. format() quotes each (%I/%L),
-- and \gexec runs the generated statement, so the names are injected safely.

\set ON_ERROR_STOP on

-- Owner role (Rails): a plain login role — not a superuser, and unable to create
-- databases or roles. It owns the database and every object the migrations create.
SELECT format('CREATE ROLE %I LOGIN', :'owner')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'owner')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
              :'owner', :'owner_password')\gexec

-- Reader role (Phoenix): a plain login role. The privileges script grants it the
-- read surface; the bootstrap only creates it with its password.
SELECT format('CREATE ROLE %I LOGIN', :'reader')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'reader')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
              :'reader', :'reader_password')\gexec

-- The database, owned by the owner role. CREATE DATABASE cannot run inside a
-- transaction, so \gexec issues it as its own statement.
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'owner')
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db', :'owner')\gexec
