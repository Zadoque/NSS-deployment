#!/bin/bash
set -eu

# The official PostgreSQL image runs this only when the volume is initialized.
# The pipeline database remains POSTGRES_DB; Java/Flyway uses POSTGRES_APP_DB.
if [ "${POSTGRES_APP_DB}" = "${POSTGRES_DB}" ]; then
  exit 0
fi

exists="$(psql --username "${POSTGRES_USER}" --dbname postgres --tuples-only --no-align \
  --command "SELECT 1 FROM pg_database WHERE datname = '$(printf '%s' "${POSTGRES_APP_DB}" | sed "s/'/''/g")'")"

if [ "${exists}" != "1" ]; then
  psql --username "${POSTGRES_USER}" --dbname postgres --command \
    "CREATE DATABASE \"${POSTGRES_APP_DB}\" OWNER \"${POSTGRES_USER}\""
fi
