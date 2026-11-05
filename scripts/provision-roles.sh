#!/usr/bin/env bash
set -Eeuo pipefail

: "${POSTGRES_ADMIN_USER:?POSTGRES_ADMIN_USER é obrigatório}"
: "${POSTGRES_ADMIN_PASSWORD:?POSTGRES_ADMIN_PASSWORD é obrigatório}"
: "${POSTGRES_DB:?POSTGRES_DB é obrigatório}"

for variable in \
  APP_RUNTIME_USER APP_RUNTIME_PASSWORD \
  APP_MIGRATOR_USER APP_MIGRATOR_PASSWORD \
  ANALYTICS_READER_USER ANALYTICS_READER_PASSWORD \
  ANALYTICS_WRITER_USER ANALYTICS_WRITER_PASSWORD \
  ANALYTICS_MIGRATOR_USER ANALYTICS_MIGRATOR_PASSWORD \
  GRAFANA_DB_USER GRAFANA_DB_PASSWORD; do
  : "${!variable:?${variable} é obrigatório}"
done

role_name() {
  [[ "$1" =~ ^[a-z_][a-z0-9_]*$ ]] || {
    printf 'Nome de role inválido: %s\n' "$1" >&2
    exit 2
  }
}

provision_role() {
  local role="$1"
  local password="$2"
  role_name "$role"
  PGPASSWORD="${POSTGRES_ADMIN_PASSWORD}" psql \
    --host "${POSTGRES_HOST:-db}" \
    --username "${POSTGRES_ADMIN_USER}" \
    --dbname "${POSTGRES_DB}" \
    --set ON_ERROR_STOP=1 \
    --set role_name="${role}" \
    --set role_password="${password}" <<'SQL'
SELECT format(
  'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT',
  :'role_name'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role_name')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'role_name', :'role_password')\gexec
SQL
}

provision_role "${APP_RUNTIME_USER}" "${APP_RUNTIME_PASSWORD}"
provision_role "${APP_MIGRATOR_USER}" "${APP_MIGRATOR_PASSWORD}"
provision_role "${ANALYTICS_READER_USER}" "${ANALYTICS_READER_PASSWORD}"
provision_role "${ANALYTICS_WRITER_USER}" "${ANALYTICS_WRITER_PASSWORD}"
provision_role "${ANALYTICS_MIGRATOR_USER}" "${ANALYTICS_MIGRATOR_PASSWORD}"
provision_role "${GRAFANA_DB_USER}" "${GRAFANA_DB_PASSWORD}"

PGPASSWORD="${POSTGRES_ADMIN_PASSWORD}" psql \
  --host "${POSTGRES_HOST:-db}" \
  --username "${POSTGRES_ADMIN_USER}" \
  --dbname "${POSTGRES_DB}" \
  --set ON_ERROR_STOP=1 \
  --set app_runtime="${APP_RUNTIME_USER}" \
  --set app_migrator="${APP_MIGRATOR_USER}" \
  --set analytics_reader="${ANALYTICS_READER_USER}" \
  --set analytics_writer="${ANALYTICS_WRITER_USER}" \
  --set analytics_migrator="${ANALYTICS_MIGRATOR_USER}" \
  --set grafana="${GRAFANA_DB_USER}" <<'SQL'
SELECT format('CREATE SCHEMA analytics AUTHORIZATION %I', :'analytics_migrator')
WHERE NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'analytics')\gexec

GRANT USAGE ON SCHEMA public TO :app_runtime;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :app_runtime;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :app_runtime;

GRANT USAGE, CREATE ON SCHEMA public TO :app_migrator;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO :app_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO :app_migrator;

GRANT USAGE ON SCHEMA analytics TO :analytics_reader, :analytics_writer, :analytics_migrator, :grafana;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO :analytics_reader;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA analytics TO :analytics_writer;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA analytics TO :analytics_writer;
GRANT USAGE, CREATE ON SCHEMA analytics TO :analytics_migrator;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO :analytics_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO :analytics_migrator;

SELECT format('GRANT SELECT ON TABLE analytics.%I TO %I', table_name, :'grafana')
FROM unnest(ARRAY[
  'pipeline_execution_metrics',
  'pipeline_publications',
  'pipeline_current_publication'
]) AS table_name
WHERE to_regclass('analytics.' || table_name) IS NOT NULL\gexec

ALTER DEFAULT PRIVILEGES FOR ROLE :app_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :app_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE :app_migrator IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :app_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE :analytics_migrator IN SCHEMA analytics
  GRANT SELECT ON TABLES TO :analytics_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE :analytics_migrator IN SCHEMA analytics
  GRANT SELECT ON TABLES TO :grafana;
SQL

printf 'Roles NSS provisionadas com separação de responsabilidades.\n'
