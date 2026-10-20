#!/usr/bin/env bash
# Smoke test for example 03: multi-export fan-out.
# Verifies the self-hosted leg (Tempo) always works; the vendor leg (Datadog)
# is checked only when DD_API_KEY is a real token.
# No `set -o pipefail` on purpose (grep -q on piped output).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed"; exit 0
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: 'docker compose' plugin not available"; exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not running"; exit 0
fi

VENDOR_MODE="walkthrough"
if [ -n "${DD_API_KEY:-}" ] && [ "${DD_API_KEY}" != "fake-key-walkthrough-only" ]; then
  VENDOR_MODE="live"
fi
echo "== Vendor mode: $VENDOR_MODE =="

echo "== Starting stack =="
docker compose up -d

echo "== Waiting for Tempo /ready (up to 60s) =="
ready=0
for i in $(seq 1 30); do
  if curl -fsS http://localhost:3200/ready >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: Tempo not ready"
  docker compose logs tempo | tail -40
  docker compose down -v
  exit 1
fi

echo "== Waiting for Tempo-leg traces (up to 90s) =="
got=0
for i in $(seq 1 45); do
  resp="$(curl -fsS -G \
    --data-urlencode 'tags=service.name=trace-gen-fanout' \
    --data-urlencode 'limit=5' \
    'http://localhost:3200/api/search' 2>/dev/null || true)"
  if echo "$resp" | grep -q '"traceID"'; then
    got=1; break
  fi
  sleep 2
done

if [ "$got" -eq 1 ]; then
  echo "OK: Tempo leg working (traces received)"
  tempo_rc=0
else
  echo "FAIL: Tempo leg did not receive traces"
  tempo_rc=1
fi

echo "== Checking Datadog leg status =="
if [ "$VENDOR_MODE" = "walkthrough" ]; then
  echo "SKIP (vendor leg): DD_API_KEY not set; Datadog will 403. This is expected."
  dd_rc=0
else
  # In live mode, verify we are NOT accumulating send_failed_spans for datadog.
  failed="$(curl -fsS http://localhost:8888/metrics 2>/dev/null \
    | grep -E '^otelcol_exporter_send_failed_spans\{.*exporter="datadog".*' \
    | awk '{print $2}' | head -1 || true)"
  failed="${failed:-0}"
  # Trim trailing zeros / float noise.
  failed_int="${failed%%.*}"
  failed_int="${failed_int:-0}"
  if [ "$failed_int" -eq 0 ]; then
    echo "OK: Datadog leg has 0 send_failed_spans"
    dd_rc=0
  else
    echo "FAIL: Datadog leg has $failed_int send_failed_spans"
    dd_rc=1
  fi
fi

echo "== Cleanup =="
docker compose down -v

if [ "$tempo_rc" -eq 0 ] && [ "$dd_rc" -eq 0 ]; then
  echo "RESULT: ALL OK"
  exit 0
fi
echo "RESULT: FAIL (tempo=$tempo_rc, datadog=$dd_rc)"
exit 1
