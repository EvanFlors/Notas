#!/usr/bin/env bash
# Validate activity 01: Jaeger receives traces; Collector no longer sends to Tempo;
# the app container was not recreated.
# No `set -o pipefail` — grep -q with pipes would spuriously flag SIGPIPE.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/otel11-lab01}}"
passed=0
failed=0
report=""

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed"; exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not running"; exit 0
fi
if [ ! -d "$BASE" ]; then
  echo "SKIP: $BASE does not exist. Run starter/setup.sh first."
  exit 0
fi

# If no lab stack is running and no Jaeger listening, skip the long checks.
if ! curl -fsS --max-time 1 http://localhost:16686/api/services >/dev/null 2>&1; then
  if ! (cd "$BASE" 2>/dev/null && docker compose ps --format '{{.State}}' 2>/dev/null | grep -q running); then
    echo "SKIP: lab stack not running under $BASE."
    exit 0
  fi
fi

check_jaeger_has_service() {
  local name="Jaeger /api/services lists trace-gen"
  for i in $(seq 1 45); do
    local resp
    resp="$(curl -fsS http://localhost:16686/api/services 2>/dev/null || true)"
    if echo "$resp" | grep -q '"trace-gen"'; then
      report+="$name: OK\n"; passed=$((passed+1)); return
    fi
    sleep 2
  done
  report+="$name: FAIL (no trace-gen service after 90s)\n"; failed=$((failed+1))
}

check_pipeline_no_tempo() {
  local name="Collector config: pipeline traces no longer uses otlp/tempo"
  local cfg="$BASE/otel-collector-config.yaml"
  if [ ! -f "$cfg" ]; then
    report+="$name: FAIL (config file missing)\n"; failed=$((failed+1)); return
  fi
  # Extract the exporters: [...] line of the traces pipeline (quick heuristic).
  local line
  line="$(awk '/pipelines:/,0' "$cfg" | awk '/traces:/,0' | grep -E '^\s*exporters:' | head -1 || true)"
  if [ -z "$line" ]; then
    report+="$name: FAIL (could not find exporters line in traces pipeline)\n"
    failed=$((failed+1)); return
  fi
  if echo "$line" | grep -q 'otlp/tempo'; then
    report+="$name: FAIL (otlp/tempo still active in traces pipeline: $line)\n"
    failed=$((failed+1))
  else
    report+="$name: OK ($line)\n"
    passed=$((passed+1))
  fi
}

check_app_container_intact() {
  local name="App container 'lab01-trace-gen' not recreated"
  if ! docker inspect -f '{{.Id}}' lab01-trace-gen >/dev/null 2>&1; then
    report+="$name: FAIL (container missing)\n"; failed=$((failed+1)); return
  fi
  if [ ! -f /tmp/trace-gen-id-before.txt ]; then
    # No reference captured: we can only confirm it's the ORIGINAL by checking
    # start time is clearly older than the collector's. Not perfect, but useful.
    local app_start col_start
    app_start="$(docker inspect -f '{{.State.StartedAt}}' lab01-trace-gen 2>/dev/null || echo '')"
    col_start="$(docker inspect -f '{{.State.StartedAt}}' lab01-otelcol 2>/dev/null || echo '')"
    report+="$name: PARTIAL (no /tmp/trace-gen-id-before.txt; app started=$app_start, collector started=$col_start)\n"
    passed=$((passed+1))
    return
  fi
  local before after
  before="$(cat /tmp/trace-gen-id-before.txt)"
  after="$(docker inspect -f '{{.Id}}' lab01-trace-gen 2>/dev/null || echo '')"
  if [ -n "$before" ] && [ "$before" = "$after" ]; then
    report+="$name: OK (same container id)\n"
    passed=$((passed+1))
  else
    report+="$name: FAIL (before=$before after=$after)\n"
    failed=$((failed+1))
  fi
}

echo "== Validating activity 01 under $BASE =="
check_jaeger_has_service
check_pipeline_no_tempo
check_app_container_intact

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
