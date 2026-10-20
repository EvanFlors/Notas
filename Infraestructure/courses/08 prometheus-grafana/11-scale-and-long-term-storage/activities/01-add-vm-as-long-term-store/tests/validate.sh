#!/usr/bin/env bash
# Validate obs-11-01 (add VictoriaMetrics as long-term store).
# 4 checks:
#   1. BASE dir exists with docker-compose.yml and prometheus.yml
#   2. prometheus.yml contains a remote_write to victoriametrics:8428
#   3. Prometheus /api/v1/query?query=up responds success  (SKIPs if container down)
#   4. VictoriaMetrics /api/v1/query?query=up responds success  (SKIPs if container down)
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `grep -q` in a pipeline, which can produce SIGPIPE (141) and be misread as failure.

BASE="${1:-${BASE_DIR:-/tmp/obs11-vm}}"
passed=0
failed=0
skipped=0
report=""

check_1_files() {
  local name="Check 1 (starter files in $BASE)"
  if [ -f "$BASE/docker-compose.yml" ] && [ -f "$BASE/prometheus.yml" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — faltan docker-compose.yml o prometheus.yml\n"
    failed=$((failed+1))
  fi
}

check_2_remote_write() {
  local name="Check 2 (remote_write en prometheus.yml)"
  if [ ! -f "$BASE/prometheus.yml" ]; then
    report+="$name: FAIL — prometheus.yml ausente\n"; failed=$((failed+1)); return
  fi
  local has_block has_url
  has_block="$(grep -c '^remote_write:' "$BASE/prometheus.yml" || true)"
  has_url="$(grep -c 'victoriametrics:8428/api/v1/write' "$BASE/prometheus.yml" || true)"
  if [ "$has_block" -ge 1 ] && [ "$has_url" -ge 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ "$has_block" -lt 1 ] && why+=" falta la sección 'remote_write:';"
    [ "$has_url"   -lt 1 ] && why+=" no apunta a http://victoriametrics:8428/api/v1/write;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_3_prometheus_up() {
  local name="Check 3 (Prometheus responde /api/v1/query up)"
  if ! command -v curl >/dev/null 2>&1; then
    report+="$name: SKIP (curl no disponible)\n"; skipped=$((skipped+1)); return
  fi
  local body
  body="$(curl -fsS --max-time 3 'http://localhost:9090/api/v1/query?query=up' 2>/dev/null || true)"
  if [ -z "$body" ]; then
    report+="$name: SKIP (Prometheus en :9090 no responde — ¿compose arriba?)\n"
    skipped=$((skipped+1)); return
  fi
  if echo "$body" | grep -q '"status":"success"'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — respuesta inesperada de Prometheus\n"
    failed=$((failed+1))
  fi
}

check_4_vm_up() {
  local name="Check 4 (VictoriaMetrics responde /api/v1/query up)"
  if ! command -v curl >/dev/null 2>&1; then
    report+="$name: SKIP (curl no disponible)\n"; skipped=$((skipped+1)); return
  fi
  local body
  body="$(curl -fsS --max-time 3 'http://localhost:8428/api/v1/query?query=up' 2>/dev/null || true)"
  if [ -z "$body" ]; then
    report+="$name: SKIP (VictoriaMetrics en :8428 no responde — ¿compose arriba?)\n"
    skipped=$((skipped+1)); return
  fi
  if echo "$body" | grep -q '"status":"success"'; then
    # Must also have at least one series (result array non-empty), meaning remote_write actually arrived.
    if echo "$body" | grep -q '"result":\[{'; then
      report+="$name: OK\n"; passed=$((passed+1))
    else
      report+="$name: FAIL — VM responde pero no tiene la serie 'up' aún (espera 20s más)\n"
      failed=$((failed+1))
    fi
  else
    report+="$name: FAIL — respuesta inesperada de VictoriaMetrics\n"
    failed=$((failed+1))
  fi
}

echo "== Validating obs-11-01 under $BASE =="

check_1_files
check_2_remote_write
check_3_prometheus_up
check_4_vm_up

echo
printf "%b" "$report"
echo
total=$((passed+failed+skipped))
echo "RESULT: $passed OK, $failed FAIL, $skipped SKIP (of $total)."

if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
