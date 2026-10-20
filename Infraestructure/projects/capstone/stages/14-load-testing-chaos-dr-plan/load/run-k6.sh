#!/usr/bin/env bash
# Capstone stage 14 — launcher for k6-script.js.
# Usage: ./run-k6.sh [BASE_URL]
# SKIPs with exit 0 if k6 is not installed.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

BASE_URL="${1:-${BASE_URL:-http://localhost:8000}}"
HERE="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$HERE/results"

if ! command -v k6 >/dev/null 2>&1; then
  echo "SKIP: k6 not installed. Install from https://k6.io/docs/getting-started/installation/"
  exit 0
fi

mkdir -p "$RESULTS_DIR"
OUT="$RESULTS_DIR/run-$(date +%Y%m%d-%H%M%S).json"

echo "== Running k6 against $BASE_URL (soak=${SOAK:-0}) =="
BASE_URL="$BASE_URL" SOAK="${SOAK:-0}" k6 run \
  --summary-export "$OUT" \
  "$HERE/k6-script.js"

echo "Summary written to $OUT"
