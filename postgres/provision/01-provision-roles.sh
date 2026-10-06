#!/bin/sh
set -eu

export PGPASSWORD="$POSTGRES_ADMIN_PASSWORD"
psql_admin() {
  psql --host db --username "$POSTGRES_ADMIN_USER" --dbname "$1" --set ON_ERROR_STOP=1 \
    --set app_db="$POSTGRES_APP_DB" \
    --set app_migrator="$NSS_APP_MIGRATOR_USER" \
    --set app_migrator_password="$NSS_APP_MIGRATOR_PASSWORD" \
    --set app_runtime="$NSS_APP_RUNTIME_USER" \
    --set app_runtime_password="$NSS_APP_RUNTIME_PASSWORD" \
    --set analytics_writer="$NSS_ANALYTICS_WRITER_USER" \
    --set analytics_writer_password="$NSS_ANALYTICS_WRITER_PASSWORD" \
    --set analytics_reader="$NSS_ANALYTICS_READER_USER" \
    --set analytics_reader_password="$NSS_ANALYTICS_READER_PASSWORD" \
    --set backup_user="$NSS_BACKUP_USER" \
    --set backup_password="$NSS_BACKUP_PASSWORD" \
    --set analytics_db="$POSTGRES_DB"
}

psql_admin postgres <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_migrator', :'app_migrator_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_migrator') \gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_runtime', :'app_runtime_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_runtime') \gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'analytics_writer', :'analytics_writer_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'analytics_writer') \gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'analytics_reader', :'analytics_reader_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'analytics_reader') \gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'backup_user', :'backup_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'backup_user') \gexec

SELECT format('ALTER ROLE %I PASSWORD %L', :'app_migrator', :'app_migrator_password') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'app_runtime', :'app_runtime_password') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'analytics_writer', :'analytics_writer_password') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'analytics_reader', :'analytics_reader_password') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'backup_user', :'backup_password') \gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_migrator')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'app_db') \gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', :'app_db', :'app_migrator') \gexec
GRANT pg_read_all_data TO :"backup_user";
SQL

psql_admin "$POSTGRES_APP_DB" <<'SQL'
ALTER SCHEMA public OWNER TO :"app_migrator";
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE :"app_db" TO :"app_runtime", :"backup_user";
GRANT USAGE ON SCHEMA public TO :"app_runtime";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_runtime";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :"app_runtime";
ALTER DEFAULT PRIVILEGES FOR ROLE :"app_migrator" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app_runtime";
ALTER DEFAULT PRIVILEGES FOR ROLE :"app_migrator" IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :"app_runtime";
SELECT format('ALTER TABLE %I.%I OWNER TO %I', schemaname, tablename, :'app_migrator')
FROM pg_tables WHERE schemaname = 'public' \gexec
SELECT format('ALTER SEQUENCE %I.%I OWNER TO %I', sequence_schema, sequence_name, :'app_migrator')
FROM information_schema.sequences WHERE sequence_schema = 'public' \gexec
SQL

psql_admin "$POSTGRES_DB" <<'SQL'
CREATE SCHEMA IF NOT EXISTS analytics AUTHORIZATION :"analytics_writer";
ALTER SCHEMA analytics OWNER TO :"analytics_writer";
REVOKE ALL ON SCHEMA analytics FROM PUBLIC;
GRANT CONNECT ON DATABASE :"analytics_db" TO :"analytics_writer", :"analytics_reader", :"backup_user";
GRANT USAGE ON SCHEMA analytics TO :"analytics_reader";
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO :"analytics_reader";
ALTER DEFAULT PRIVILEGES FOR ROLE :"analytics_writer" IN SCHEMA analytics GRANT SELECT ON TABLES TO :"analytics_reader";
SELECT format('ALTER TABLE %I.%I OWNER TO %I', schemaname, tablename, :'analytics_writer')
FROM pg_tables WHERE schemaname = 'analytics' \gexec
SELECT format('ALTER SEQUENCE %I.%I OWNER TO %I', sequence_schema, sequence_name, :'analytics_writer')
FROM information_schema.sequences WHERE sequence_schema = 'analytics' \gexec
SQL
