#!/usr/bin/env bash
# deploy-schema-postgres.sh — Apply all schema/postgres/*.sql files to a
# PostgreSQL instance in declaration order.
#
# Environment variables (all have defaults for local dev):
#   PGHOST      Postgres hostname      (default: localhost)
#   PGPORT      Postgres port          (default: 5432)
#   PGUSER      Postgres user          (default: capacito)
#   PGPASSWORD  Postgres password      (default: capacito)
#   PGDATABASE  Postgres database      (default: capacito)
#
# Usage:
#   ./scripts/deploy-schema-postgres.sh
#   PGHOST=my-server PGDATABASE=prod ./scripts/deploy-schema-postgres.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_DIR="${REPO_ROOT}/schema/postgres"

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-capacito}"
export PGPASSWORD="${PGPASSWORD:-capacito}"
export PGDATABASE="${PGDATABASE:-capacito}"

echo "[postgres] Connecting to ${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}"

# Wait for Postgres to be ready (important in CI where the container starts async)
MAX_TRIES=30
for i in $(seq 1 ${MAX_TRIES}); do
  if pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -q; then
    echo "[postgres] Ready."
    break
  fi
  if [ "${i}" -eq "${MAX_TRIES}" ]; then
    echo "[postgres] ERROR: Timed out waiting for Postgres to be ready." >&2
    exit 1
  fi
  echo "[postgres] Waiting for Postgres... (${i}/${MAX_TRIES})"
  sleep 2
done

# Ensure the target database exists
psql --host="${PGHOST}" --port="${PGPORT}" --username="${PGUSER}" \
     --dbname="postgres" \
     --command="SELECT 1 FROM pg_database WHERE datname = '${PGDATABASE}'" \
  | grep -q 1 || \
  psql --host="${PGHOST}" --port="${PGPORT}" --username="${PGUSER}" \
       --dbname="postgres" \
       --command="CREATE DATABASE ${PGDATABASE};"

# Apply each SQL file in sorted order
SQL_FILES=("${SCHEMA_DIR}"/*.sql)
if [ ${#SQL_FILES[@]} -eq 0 ] || [ ! -f "${SQL_FILES[0]}" ]; then
  echo "[postgres] No SQL files found in ${SCHEMA_DIR}" >&2
  exit 1
fi

for sql_file in "${SQL_FILES[@]}"; do
  echo "[postgres] Applying $(basename "${sql_file}")..."
  psql \
    --host="${PGHOST}" \
    --port="${PGPORT}" \
    --username="${PGUSER}" \
    --dbname="${PGDATABASE}" \
    --set=ON_ERROR_STOP=1 \
    --file="${sql_file}"
done

echo "[postgres] Schema deployment complete."
