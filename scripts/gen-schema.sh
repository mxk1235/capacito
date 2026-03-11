#!/usr/bin/env bash
# gen-schema.sh — Run protoc with protoc-gen-sql to generate SQL DDL for all
# dialects from proto/objects/*.proto. Outputs to schema/<dialect>/<name>.sql
#
# Usage:
#   ./scripts/gen-schema.sh                  # all dialects
#   ./scripts/gen-schema.sh --dialect=postgres
#   ./scripts/gen-schema.sh --dialect=spanner
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_PATH="${REPO_ROOT}/proto"
OBJECTS_DIR="${PROTO_PATH}/objects"
OUT_DIR="${REPO_ROOT}/schema"
PLUGIN="${REPO_ROOT}/tools/protoc-gen-sql"

# Parse optional --dialect flag
DIALECT_OPT=""
for arg in "$@"; do
  case "$arg" in
    --dialect=*) DIALECT_OPT="${arg#--dialect=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# Build --sql_opt string
if [ -n "${DIALECT_OPT}" ]; then
  SQL_OPT="dialect=${DIALECT_OPT}"
else
  SQL_OPT="dialect=all"
fi

mkdir -p "${OUT_DIR}"

PROTO_FILES=("${OBJECTS_DIR}"/*.proto)
if [ ${#PROTO_FILES[@]} -eq 0 ]; then
  echo "No .proto files found in ${OBJECTS_DIR}" >&2
  exit 1
fi

echo "[gen-schema] Generating SQL DDL (${SQL_OPT})..."
protoc \
  --proto_path="${PROTO_PATH}" \
  --proto_path="/usr/include" \
  --plugin="protoc-gen-sql=${PLUGIN}" \
  --sql_opt="${SQL_OPT}" \
  --sql_out="${OUT_DIR}" \
  "${PROTO_FILES[@]}"

echo "[gen-schema] Done."
find "${OUT_DIR}" -name "*.sql" | sort | sed 's|^|  |'
