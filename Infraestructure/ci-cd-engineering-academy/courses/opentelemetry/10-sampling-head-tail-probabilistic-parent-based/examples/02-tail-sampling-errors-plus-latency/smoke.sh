#!/usr/bin/env bash
# Smoke test for the tail_sampling example.
# NOTE: no `set -o pipefail`; some checks pipe into `grep -q` which may SIGPIPE.
set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="/tmp/otel10-tail"
OUT_FILE="$OUT_DIR/otel10-tail-out.json"
VENV="/tmp/otel10-tail-venv"
CONTAINER="otel10-collector"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$OUT_DIR" "$VENV"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no disponible"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde"
  exit 0
fi

mkdir -p "$OUT_DIR"
: > "$OUT_FILE"
chmod 666 "$OUT_FILE"

echo "== starting collector =="
docker run -d --rm --name "$CONTAINER" \
  -p 4317:4317 \
  -v "$HERE/collector-config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  -v "$OUT_DIR:/out" \
  otel/opentelemetry-collector-contrib:0.108.0 \
  --config=/etc/otelcol-contrib/config.yaml >/dev/null

# give the collector a moment to bind (the contrib image is distroless, so no exec probing)
sleep 4

echo "== python venv =="
python3 -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install -q -r "$HERE/requirements.txt"

echo "== generate load =="
python3 "$HERE/load.py"

echo "== waiting for decision_wait =="
sleep 8

echo "== flush file exporter =="
# File exporter buffers; stopping container flushes. We stop then read.
docker stop "$CONTAINER" >/dev/null 2>&1 || true
sleep 1

if [ ! -s "$OUT_FILE" ]; then
  echo "FAIL: $OUT_FILE vacío"
  exit 1
fi

errors=$(grep -o '"intentional"' "$OUT_FILE" | wc -l | tr -d ' ')
slow=$(grep -o '"slow-ok"' "$OUT_FILE" | wc -l | tr -d ' ')
fast=$(grep -o '"fast-ok"' "$OUT_FILE" | wc -l | tr -d ' ')

echo "== counts: errors=$errors slow=$slow fast=$fast =="

status=0
if [ "$errors" -lt 45 ]; then
  echo "FAIL: expected ~50 error spans, got $errors"
  status=1
fi
if [ "$slow" -lt 90 ]; then
  echo "FAIL: expected ~100 slow spans, got $slow"
  status=1
fi
if [ "$fast" -lt 3 ] || [ "$fast" -gt 40 ]; then
  echo "FAIL: expected ~15 fast spans (10%), got $fast"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "OK"
fi
exit "$status"
