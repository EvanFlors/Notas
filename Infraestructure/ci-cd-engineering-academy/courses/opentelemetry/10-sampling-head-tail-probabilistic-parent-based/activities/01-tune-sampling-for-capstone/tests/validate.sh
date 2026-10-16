#!/usr/bin/env bash
# Validate the tail-sampling output of otel-10-01.
# Note: NO `set -o pipefail`; many checks pipe into `grep -q` which may SIGPIPE
# the upstream `grep -o` early.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/otel10-01}}"
OUT="$BASE/out.json"

if [ ! -s "$OUT" ]; then
  echo "FAIL: $OUT no existe o está vacío. Corre starter/run-lab.sh primero."
  exit 1
fi

errors=$(grep -o '"intentional"' "$OUT" | wc -l | tr -d ' ')
slow=$(grep -o '"slow-ok"' "$OUT" | wc -l | tr -d ' ')
fast=$(grep -o '"fast-ok"' "$OUT" | wc -l | tr -d ' ')

echo "== conteos: errors=$errors slow=$slow fast=$fast =="

status=0
if [ "$errors" -lt 50 ]; then
  echo "FAIL: errors=$errors; se esperaban 50 (100% de los errores)."
  status=1
fi
if [ "$slow" -lt 90 ]; then
  echo "FAIL: slow=$slow; se esperaban ~100 (100% de slow)."
  status=1
fi
if [ "$fast" -lt 3 ] || [ "$fast" -gt 40 ]; then
  echo "FAIL: fast=$fast; se esperaba ~15 (10% de 150)."
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "OK"
fi
exit "$status"
