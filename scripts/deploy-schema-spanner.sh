#!/usr/bin/env bash
# deploy-schema-spanner.sh — Apply all schema/spanner/*.sql files to a
# Cloud Spanner instance (real or emulator) using the gcloud CLI.
#
# Environment variables:
#   SPANNER_PROJECT   GCP project ID            (default: capacito-local)
#   SPANNER_INSTANCE  Spanner instance ID        (default: capacito)
#   SPANNER_DATABASE  Spanner database ID        (default: capacito)
#   SPANNER_EMULATOR_HOST
#                     If set, gcloud and the Spanner client libraries route
#                     traffic to the emulator instead of Cloud Spanner.
#                     (default: localhost:9010 — the emulator's gRPC port)
#
# In CI the Spanner emulator is used automatically.
# For production deployments, unset SPANNER_EMULATOR_HOST and ensure
# Application Default Credentials are configured.
#
# Usage (emulator):
#   SPANNER_EMULATOR_HOST=localhost:9010 ./scripts/deploy-schema-spanner.sh
#
# Usage (real Spanner):
#   SPANNER_PROJECT=my-project \
#   SPANNER_INSTANCE=my-instance \
#   SPANNER_DATABASE=capacito \
#   ./scripts/deploy-schema-spanner.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_DIR="${REPO_ROOT}/schema/spanner"

SPANNER_PROJECT="${SPANNER_PROJECT:-capacito-local}"
SPANNER_INSTANCE="${SPANNER_INSTANCE:-capacito}"
SPANNER_DATABASE="${SPANNER_DATABASE:-capacito}"
export SPANNER_EMULATOR_HOST="${SPANNER_EMULATOR_HOST:-localhost:9010}"

echo "[spanner] Project:  ${SPANNER_PROJECT}"
echo "[spanner] Instance: ${SPANNER_INSTANCE}"
echo "[spanner] Database: ${SPANNER_DATABASE}"
echo "[spanner] Emulator: ${SPANNER_EMULATOR_HOST:-<real Cloud Spanner>}"

# Wait for the emulator to be reachable
if [ -n "${SPANNER_EMULATOR_HOST:-}" ]; then
  EMULATOR_HOST="${SPANNER_EMULATOR_HOST%%:*}"
  EMULATOR_PORT="${SPANNER_EMULATOR_HOST##*:}"
  MAX_TRIES=30
  for i in $(seq 1 ${MAX_TRIES}); do
    if nc -z "${EMULATOR_HOST}" "${EMULATOR_PORT}" 2>/dev/null; then
      echo "[spanner] Emulator is ready."
      break
    fi
    if [ "${i}" -eq "${MAX_TRIES}" ]; then
      echo "[spanner] ERROR: Timed out waiting for Spanner emulator." >&2
      exit 1
    fi
    echo "[spanner] Waiting for emulator... (${i}/${MAX_TRIES})"
    sleep 2
  done
fi

# Ensure the instance exists (emulator only — real Spanner instances are
# provisioned via Terraform/gcloud outside of this script)
if [ -n "${SPANNER_EMULATOR_HOST:-}" ]; then
  gcloud spanner instances describe "${SPANNER_INSTANCE}" \
    --project="${SPANNER_PROJECT}" \
    --quiet 2>/dev/null || \
  gcloud spanner instances create "${SPANNER_INSTANCE}" \
    --project="${SPANNER_PROJECT}" \
    --config=emulator-config \
    --description="capacito emulator instance" \
    --nodes=1 \
    --quiet
fi

# Ensure the database exists
gcloud spanner databases describe "${SPANNER_DATABASE}" \
  --instance="${SPANNER_INSTANCE}" \
  --project="${SPANNER_PROJECT}" \
  --quiet 2>/dev/null || \
gcloud spanner databases create "${SPANNER_DATABASE}" \
  --instance="${SPANNER_INSTANCE}" \
  --project="${SPANNER_PROJECT}" \
  --quiet

# Collect all DDL statements from schema files
# gcloud ddl update takes all statements in a single call; Spanner applies
# them transactionally.
SQL_FILES=("${SCHEMA_DIR}"/*.sql)
if [ ${#SQL_FILES[@]} -eq 0 ] || [ ! -f "${SQL_FILES[0]}" ]; then
  echo "[spanner] No SQL files found in ${SCHEMA_DIR}" >&2
  exit 1
fi

# Strip comment lines and blank lines, concatenate, split on ';' boundaries
COMBINED_DDL=""
for sql_file in "${SQL_FILES[@]}"; do
  echo "[spanner] Reading $(basename "${sql_file}")..."
  COMBINED_DDL+=$'\n'"$(grep -v '^\s*--' "${sql_file}" | grep -v '^\s*$')"
done

# Write to a temp file for gcloud
TMPFILE="$(mktemp /tmp/capacito-spanner-ddl-XXXXXX.sql)"
trap 'rm -f "${TMPFILE}"' EXIT
echo "${COMBINED_DDL}" > "${TMPFILE}"

echo "[spanner] Applying DDL..."
gcloud spanner databases ddl update "${SPANNER_DATABASE}" \
  --instance="${SPANNER_INSTANCE}" \
  --project="${SPANNER_PROJECT}" \
  --ddl-file="${TMPFILE}" \
  --quiet

echo "[spanner] Schema deployment complete."
