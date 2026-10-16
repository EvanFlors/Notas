#!/usr/bin/env bash
# Validate activity 01: launches collector in docker, sends 3 signals, verifies 3 jsonl files.
# Note: pipefail is intentionally NOT enabled because some probes pipe into `grep -q`
# which produces SIGPIPE on the producer. pipefail would mark these as spurious failures.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STARTER_DIR="$(cd "$SCRIPT_DIR/../starter" && pwd)"
CONFIG="$STARTER_DIR/config.yaml"

OUT_DIR="${OUT_DIR:-/tmp/otel-lab}"
NAME="otel-lab-collector-test"
COLLECTOR_IMAGE="${COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:latest}"
TELEMETRYGEN_IMAGE="${TELEMETRYGEN_IMAGE:-ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest}"

skip() {
  echo "SKIP: $*"
  exit 0
}

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$OUT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# --- SKIP if docker is unavailable ---------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  skip "docker binary not found"
fi
if ! docker info >/dev/null 2>&1; then
  skip "docker daemon not reachable"
fi
if [ ! -f "$CONFIG" ]; then
  echo "FAIL: $CONFIG missing"
  exit 1
fi

# --- 1) Validate config with the Collector binary -----------------------
echo "== validate config =="
if ! docker run --rm \
      -v "$CONFIG:/c.yaml:ro" \
      "$COLLECTOR_IMAGE" validate --config=/c.yaml; then
  echo "FAIL: otelcol-contrib validate rejected the config"
  exit 1
fi

# --- 2) Prepare output dir (writable by container user) -----------------
mkdir -p "$OUT_DIR"
chmod 777 "$OUT_DIR"

# --- 3) Launch collector in the background ------------------------------
echo "== launch collector =="
docker rm -f "$NAME" >/dev/null 2>&1 || true

# Use non-standard host ports to avoid colliding with any existing collector
# listening on 4317/4318 locally. Override with HOST_GRPC_PORT / HOST_HTTP_PORT.
HOST_GRPC_PORT="${HOST_GRPC_PORT:-14317}"
HOST_HTTP_PORT="${HOST_HTTP_PORT:-14318}"
PORT_ARGS=(-p "${HOST_GRPC_PORT}:4317" -p "${HOST_HTTP_PORT}:4318")
NET_ARGS=()
TG_ENDPOINT="host.docker.internal:${HOST_GRPC_PORT}"
if [ "$(uname -s)" = "Linux" ]; then
  # On Linux reuse the host network. telemetrygen reaches the collector on
  # localhost:4317 directly; HOST_GRPC_PORT does not apply in this mode.
  PORT_ARGS=()
  NET_ARGS=(--network host)
  TG_ENDPOINT="localhost:4317"
fi

docker run -d --rm --name "$NAME" \
  "${PORT_ARGS[@]}" \
  -v "$CONFIG:/etc/otelcol/config.yaml:ro" \
  -v "$OUT_DIR:/out" \
  "$COLLECTOR_IMAGE" --config=/etc/otelcol/config.yaml >/dev/null

# Wait for the collector to accept connections (max ~15s).
ready=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if docker logs "$NAME" 2>&1 | grep -q "Everything is ready"; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: collector did not report ready in 15s. Logs:"
  docker logs "$NAME" 2>&1 | tail -n 30 || true
  exit 1
fi

# --- 4) Send telemetry (traces, metrics, logs) --------------------------
echo "== send telemetry =="
for signal in traces metrics logs; do
  echo "  -> $signal"
  # Each subcommand has its own count flag: --traces / --metrics / --logs.
  if ! docker run --rm "${NET_ARGS[@]}" "$TELEMETRYGEN_IMAGE" "$signal" \
         --otlp-insecure \
         --otlp-endpoint "$TG_ENDPOINT" \
         "--${signal}" 10 \
         --duration 2s \
         --service "test-service" >/dev/null 2>&1; then
    echo "FAIL: telemetrygen $signal failed"
    docker logs "$NAME" 2>&1 | tail -n 30 || true
    exit 1
  fi
done

# Give the batch processor time to flush (timeout: 1s).
sleep 3

# --- 5) Assert files exist and are non-empty ----------------------------
echo "== verify output =="
pass=0
fail=0
for name in traces metrics logs; do
  f="$OUT_DIR/$name.jsonl"
  if [ -s "$f" ]; then
    echo "  OK  $name.jsonl ($(wc -c <"$f") bytes)"
    pass=$((pass+1))
  else
    echo "  FAIL $name.jsonl missing or empty"
    fail=$((fail+1))
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: $pass/3 signals landed. PASS"
  exit 0
fi

echo "RESULT: $pass/3 signals landed. FAIL"
echo "--- collector logs (last 40 lines) ---"
docker logs "$NAME" 2>&1 | tail -n 40 || true
exit 1
