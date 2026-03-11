#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

echo "[capacito] Configuring (${BUILD_TYPE})..."
cmake -S . -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

echo "[capacito] Building..."
cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo "[capacito] Done. Binaries in ./${BUILD_DIR}/"
