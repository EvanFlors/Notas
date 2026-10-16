#!/usr/bin/env bash
# Validate obs-05-02: labels normalized and noisy metrics dropped.
#
# Note: deliberately NO `set -o pipefail`: we pipe curl into grep -q, which may close
# the pipe early on first match causing curl to receive SIGPIPE (exit 141) — pipefail
# would wrongly treat that as failure.
set -eu

PROM_URL="${PROM_URL:-http://localhost:9090}"
SCRATCH="${SCRATCH:-/tmp/obs-05-02-validate}"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

passed=0
failed=0
report=""

skip_if_down() {
  if ! curl -fsS --max-time 3 "$PROM_URL/-/ready" >/dev/null 2>&1; then
    echo "SKIP: Prometheus not reachable at $PROM_URL (stack not running?)."
    echo "      Run 'docker compose up -d' in starter/ and retry."
    exit 0
  fi
}

query() {
  curl -fsS --data-urlencode "query=$1" "$PROM_URL/api/v1/query" > "$SCRATCH/resp.json"
}

num_results() {
  grep -o '"value"' "$SCRATCH/resp.json" | wc -l | tr -d ' '
}

check_env_team_global() {
  local name="env=lab AND team=sre on 'up' across all jobs"
  query 'up{env="lab",team="sre"}'
  local n
  n="$(num_results)"
  # Expect at least 3 (prometheus + node + 2 blackbox probes = 4; be lenient).
  if [ "$n" -ge 3 ]; then
    report+="$name: OK (n=$n)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (n=$n; expected >=3). Add external_labels or per-job relabel.\n"
    failed=$((failed+1))
  fi
}

check_node_instance() {
  local name="node job has instance=node1"
  query 'up{job="node",instance="node1"}'
  if [ "$(num_results)" -ge 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (instance=node1 not set on job=node).\n"
    failed=$((failed+1))
  fi
}

check_blackbox_instance_is_url() {
  local name="blackbox instance equals probed URL"
  query 'up{job="blackbox",instance="https://example.com"}'
  if [ "$(num_results)" -ge 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (instance should be the probed URL; check __param_target mapping).\n"
    failed=$((failed+1))
  fi
}

check_promhttp_total_dropped() {
  local name="promhttp_metric_handler_requests_total dropped"
  query 'count({__name__="promhttp_metric_handler_requests_total"})'
  if [ "$(num_results)" -eq 0 ] || grep -q '"0"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (series still present; add metric_relabel_configs drop).\n"
    failed=$((failed+1))
  fi
}

check_promhttp_inflight_dropped() {
  local name="promhttp_metric_handler_requests_in_flight dropped"
  query 'count({__name__="promhttp_metric_handler_requests_in_flight"})'
  if [ "$(num_results)" -eq 0 ] || grep -q '"0"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (series still present; add metric_relabel_configs drop).\n"
    failed=$((failed+1))
  fi
}

check_probe_success_present() {
  local name="probe_success survived"
  query 'count(probe_success == 1)'
  if [ "$(num_results)" -ge 1 ] && ! grep -q '"0"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (no successful probe; did you break blackbox config?).\n"
    failed=$((failed+1))
  fi
}

echo "== obs-05-02 validate =="
skip_if_down
check_env_team_global
check_node_instance
check_blackbox_instance_is_url
check_promhttp_total_dropped
check_promhttp_inflight_dropped
check_probe_success_present

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
