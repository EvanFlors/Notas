#!/usr/bin/env bash
# Example 02 — queue persistence end-to-end demo with docker.
# No pipefail (grep -q + docker pipe would spuriously fail).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="/tmp/otel-09-ex02"
STORAGE="$WORK/storage"
DATA="$WORK/data"

skip() { echo "SKIP: $1"; exit 0; }

command -v docker >/dev/null 2>&1 || skip "docker no instalado"
docker info >/dev/null 2>&1          || skip "docker daemon no responde"

mkdir -p "$STORAGE" "$DATA"
chmod 777 "$STORAGE" "$DATA"

NET="otel09ex02"
IMG="otel/opentelemetry-collector-contrib:0.109.0"
TG_IMG="ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.109.0"

cleanup_containers() {
  docker rm -f backend collector telemetrygen >/dev/null 2>&1 || true
}
trap cleanup_containers EXIT

docker network rm "$NET" >/dev/null 2>&1 || true
docker network create "$NET" >/dev/null

echo "== 1. levanta backend (otel collector con exporter file) =="
docker run -d --rm --name backend --network "$NET" \
  -v "$HERE/backend-config.yaml:/etc/otelcol/config.yaml:ro" \
  -v "$DATA:/data" \
  "$IMG" --config=/etc/otelcol/config.yaml >/dev/null

sleep 3

echo "== 2. levanta collector con file_storage =="
docker run -d --rm --name collector --network "$NET" \
  -v "$HERE/collector-config.yaml:/etc/otelcol/config.yaml:ro" \
  -v "$STORAGE:/var/lib/otelcol/storage" \
  -p 4317:4317 \
  "$IMG" --config=/etc/otelcol/config.yaml >/dev/null

sleep 3

send_spans() {
  local n="$1"
  docker run --rm --name telemetrygen --network "$NET" \
    "$TG_IMG" traces --otlp-endpoint=collector:4317 --otlp-insecure \
    --traces="$n" --service=demo-app >/dev/null 2>&1 || true
}

echo "== 3. envía 50 spans con backend ARRIBA =="
send_spans 50
sleep 4
baseline=$(wc -l < "$DATA/out.json" 2>/dev/null || echo 0)
echo "   backend líneas tras ronda 1: $baseline"

echo "== 4. tira el backend =="
docker rm -f backend >/dev/null

echo "== 5. envía 50 spans más (deben ir a la cola en disco) =="
send_spans 50
sleep 4
qsize=$(du -sb "$STORAGE" 2>/dev/null | awk '{print $1}')
echo "   tamaño cola en disco: $qsize bytes"

echo "== 6. reinicia el collector (verifica que la cola persiste) =="
docker rm -f collector >/dev/null
docker run -d --rm --name collector --network "$NET" \
  -v "$HERE/collector-config.yaml:/etc/otelcol/config.yaml:ro" \
  -v "$STORAGE:/var/lib/otelcol/storage" \
  -p 4317:4317 \
  "$IMG" --config=/etc/otelcol/config.yaml >/dev/null
sleep 3

echo "== 7. levanta backend otra vez =="
docker run -d --rm --name backend --network "$NET" \
  -v "$HERE/backend-config.yaml:/etc/otelcol/config.yaml:ro" \
  -v "$DATA:/data" \
  "$IMG" --config=/etc/otelcol/config.yaml >/dev/null
sleep 8

after=$(wc -l < "$DATA/out.json" 2>/dev/null || echo 0)
echo "   backend líneas tras recovery: $after"

if [ "$after" -gt "$baseline" ]; then
  echo "OK: la cola persistida se vació hacia el backend tras recovery."
else
  echo "WARN: el backend no creció (revisa docker logs collector / backend)."
fi

echo
echo "Para limpiar:  bash $HERE/cleanup.sh"
trap - EXIT
