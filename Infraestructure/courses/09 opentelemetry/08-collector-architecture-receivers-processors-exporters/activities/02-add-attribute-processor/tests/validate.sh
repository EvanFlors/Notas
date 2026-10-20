#!/usr/bin/env bash
# Validate activity 02: student added an attributes/resource/transform processor
# that stamps deployment.environment=prod on all spans and metric data points.
#
# Note: pipefail is intentionally NOT enabled because some probes pipe into `grep -q`
# which can produce SIGPIPE on the upstream command. pipefail would mark those as
# spurious failures.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STARTER_DIR="$(cd "$SCRIPT_DIR/../starter" && pwd)"
CONFIG="$STARTER_DIR/config.yaml"

OUT_DIR="${OUT_DIR:-/tmp/otel-lab-02}"
NAME="otel-lab-collector-02"
COLLECTOR_IMAGE="${COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:latest}"
TELEMETRYGEN_IMAGE="${TELEMETRYGEN_IMAGE:-ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest}"

skip() { echo "SKIP: $*"; exit 0; }

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$OUT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# --- SKIP if docker unavailable -----------------------------------------
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

# --- 1) Static sanity: the student actually added a processor -----------
# We look for *any* of the three valid processor types referenced in a pipeline.
# If none appears, no need to even start the collector.
#
# Grep without pipefail: grep returns 1 if no match; we handle that explicitly.
# The processor type must be defined (top-level key under `processors:`) AND
# referenced in at least two pipeline `processors: [...]` list lines (traces + metrics).
mentioned_processor=""
if grep -Eq '^[[:space:]]*(attributes|resource|transform)(/[a-zA-Z0-9_-]+)?:[[:space:]]*$' "$CONFIG"; then
  mentioned_processor="yes"
fi

# Count pipeline `processors: [...]` lines that reference one of the three types.
# grep returns 1 on no-match, which with `set -e` would abort — guard explicitly.
pipeline_refs=0
pipeline_refs="$(grep -E '^[[:space:]]+processors:[[:space:]]*\[' "$CONFIG" \
                 | grep -cE '(attributes|resource|transform)' || true)"

if [ -z "$mentioned_processor" ] || [ "${pipeline_refs:-0}" -lt 2 ]; then
  echo "FAIL: starter/config.yaml must DEFINE an attributes/resource/transform processor"
  echo "      and REFERENCE it in both 'traces' and 'metrics' pipeline processor lists."
  echo "      (defined=$mentioned_processor, pipeline references found=$pipeline_refs)"
  exit 1
fi

# --- 2) Validate config with the Collector binary -----------------------
echo "== validate config =="
if ! docker run --rm -v "$CONFIG:/c.yaml:ro" "$COLLECTOR_IMAGE" validate --config=/c.yaml; then
  echo "FAIL: otelcol-contrib validate rejected the config"
  exit 1
fi

# --- 3) Launch collector ------------------------------------------------
mkdir -p "$OUT_DIR"
chmod 777 "$OUT_DIR"
docker rm -f "$NAME" >/dev/null 2>&1 || true

HOST_GRPC_PORT="${HOST_GRPC_PORT:-14327}"
HOST_HTTP_PORT="${HOST_HTTP_PORT:-14328}"
PORT_ARGS=(-p "${HOST_GRPC_PORT}:4317" -p "${HOST_HTTP_PORT}:4318")
NET_ARGS=()
TG_ENDPOINT="host.docker.internal:${HOST_GRPC_PORT}"
if [ "$(uname -s)" = "Linux" ]; then
  PORT_ARGS=()
  NET_ARGS=(--network host)
  TG_ENDPOINT="localhost:4317"
fi

echo "== launch collector =="
docker run -d --rm --name "$NAME" \
  "${PORT_ARGS[@]}" \
  -v "$CONFIG:/etc/otelcol/config.yaml:ro" \
  -v "$OUT_DIR:/out" \
  "$COLLECTOR_IMAGE" --config=/etc/otelcol/config.yaml >/dev/null

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

# --- 4) Send traces and metrics -----------------------------------------
echo "== send telemetry =="
for signal in traces metrics; do
  echo "  -> $signal"
  # Each subcommand has its own count flag: --traces / --metrics.
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

sleep 3

# --- 5) Assert the attribute landed in both files -----------------------
echo "== verify attribute =="
pass=0
fail=0
for f in traces metrics; do
  path="$OUT_DIR/$f.jsonl"
  if [ ! -s "$path" ]; then
    echo "  FAIL $f.jsonl missing or empty"
    fail=$((fail+1))
    continue
  fi
  # Must contain BOTH the key and the value 'prod' somewhere.
  has_key=""
  has_val=""
  if grep -q 'deployment.environment' "$path"; then has_key="yes"; fi
  if grep -q '"prod"' "$path"; then has_val="yes"; fi
  if [ -n "$has_key" ] && [ -n "$has_val" ]; then
    echo "  OK  $f.jsonl has deployment.environment=prod"
    pass=$((pass+1))
  else
    echo "  FAIL $f.jsonl missing deployment.environment or 'prod'"
    fail=$((fail+1))
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: $pass/2 signals carry deployment.environment=prod. PASS"
  exit 0
fi
echo "RESULT: $pass/2 signals carry deployment.environment=prod. FAIL"
echo "--- collector logs (last 40 lines) ---"
docker logs "$NAME" 2>&1 | tail -n 40 || true
exit 1
