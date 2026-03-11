#!/usr/bin/env bash
# gen-schema.sh — Run protoc with the protoc-gen-sql plugin to generate SQL DDL
# from all proto/objects/*.proto files into schema/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_PATH="${REPO_ROOT}/proto"
OBJECTS_DIR="${PROTO_PATH}/objects"
OUT_DIR="${REPO_ROOT}/schema"
PLUGIN="${REPO_ROOT}/tools/protoc-gen-sql"

mkdir -p "${OUT_DIR}"

# Collect all object proto files
PROTO_FILES=("${OBJECTS_DIR}"/*.proto)
if [ ${#PROTO_FILES[@]} -eq 0 ]; then
  echo "No .proto files found in ${OBJECTS_DIR}" >&2
  exit 1
fi

echo "[gen-schema] Generating SQL DDL..."
protoc \
  --proto_path="${PROTO_PATH}" \
  --proto_path="/usr/include" \
  --plugin="protoc-gen-sql=${PLUGIN}" \
  --sql_out="${OUT_DIR}" \
  "${PROTO_FILES[@]}"

echo "[gen-schema] Done. Generated files in ${OUT_DIR}/"
ls -1 "${OUT_DIR}"/*.sql
