#!/usr/bin/env bash
# Launch collector + python load for the capstone sampling lab.
# NOTE: no pipefail; `grep -q` can SIGPIPE upstream producers.
set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="/tmp/otel10-01"
OUT_FILE="$OUT_DIR/out.json"
VENV="/tmp/otel10-01-venv"
CONTAINER="otel10-01-collector"
PORT=14317

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
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

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
: > "$OUT_FILE"
chmod 666 "$OUT_FILE"

echo "== starting collector on :$PORT =="
docker run -d --rm --name "$CONTAINER" \
  -p "${PORT}:4317" \
  -v "$HERE/collector-config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  -v "$OUT_DIR:/out" \
  otel/opentelemetry-collector-contrib:0.108.0 \
  --config=/etc/otelcol-contrib/config.yaml >/dev/null

sleep 4

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "FAIL: collector no quedó en Up (revisa el YAML)"
  docker logs "$CONTAINER" 2>&1 | tail -40 || true
  exit 1
fi

echo "== python venv =="
python3 -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install -q -r "$HERE/requirements.txt"

echo "== load =="
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:${PORT}" python3 "$HERE/load.py"

echo "== wait decision_wait =="
sleep 8

echo "== stop container (flush file exporter) =="
docker stop "$CONTAINER" >/dev/null 2>&1 || true
sleep 1

if [ ! -s "$OUT_FILE" ]; then
  echo "FAIL: $OUT_FILE vacío. Revisa la configuración del Collector."
  exit 1
fi

echo "== output ready: $OUT_FILE =="
echo "Run: bash tests/validate.sh $OUT_DIR"
