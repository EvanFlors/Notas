#!/usr/bin/env bash
# Validate activity 01: Loki ready, Alloy up, logs flowing, Grafana datasource.
# No `set -o pipefail` — grep -q with pipes would spuriously flag SIGPIPE.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/obs13-lab01}}"
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

# Fast skip: if the lab stack isn't actually running (nothing listening on
# Loki's port AND no lab compose project is up), avoid the long polling.
if ! curl -fsS --max-time 1 http://localhost:3100/ready >/dev/null 2>&1; then
  if ! (cd "$BASE" 2>/dev/null && docker compose ps --format '{{.State}}' 2>/dev/null | grep -q running); then
    echo "SKIP: lab stack is not running under $BASE. 'cd $BASE && docker compose up -d' first."
    exit 0
  fi
fi

check_loki_ready() {
  local name="Loki /ready"
  for i in $(seq 1 30); do
    if curl -fsS http://localhost:3100/ready >/dev/null 2>&1; then
      report+="$name: OK\n"; passed=$((passed+1)); return
    fi
    sleep 2
  done
  report+="$name: FAIL (no response in 60s)\n"; failed=$((failed+1))
}

check_alloy_running() {
  local name="Alloy container running"
  cd "$BASE"
  local status
  status="$(docker compose ps --format '{{.Service}} {{.State}}' 2>/dev/null | grep '^alloy ' | awk '{print $2}' || true)"
  if [ "$status" = "running" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (state='$status')\n"; failed=$((failed+1))
  fi
}

check_logs_flowing() {
  local name="Logs flowing for {app=\"demo-app\"}"
  for i in $(seq 1 45); do
    local resp
    resp="$(curl -fsS -G \
      --data-urlencode 'query={app="demo-app"}' \
      --data-urlencode 'limit=5' \
      'http://localhost:3100/loki/api/v1/query_range' 2>/dev/null || true)"
    if echo "$resp" | grep -q '"values"'; then
      report+="$name: OK\n"; passed=$((passed+1)); return
    fi
    sleep 2
  done
  report+="$name: FAIL (no values in 90s)\n"; failed=$((failed+1))
}

check_grafana_datasource() {
  local name="Grafana has Loki datasource"
  local resp
  resp="$(curl -fsS -u admin:admin http://localhost:3000/api/datasources/name/Loki 2>/dev/null || true)"
  if echo "$resp" | grep -q '"type":"loki"'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (datasource missing)\n"; failed=$((failed+1))
  fi
}

echo "== Validating activity 01 under $BASE =="
check_loki_ready
check_alloy_running
check_logs_flowing
check_grafana_datasource

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/4 checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
