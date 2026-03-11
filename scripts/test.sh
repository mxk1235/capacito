#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"

if [ ! -d "${BUILD_DIR}" ]; then
  echo "[capacito] Build directory not found. Run ./scripts/build.sh first."
  exit 1
fi

echo "[capacito] Running tests..."
ctest --test-dir "${BUILD_DIR}" --output-on-failure --parallel "$(nproc)"
