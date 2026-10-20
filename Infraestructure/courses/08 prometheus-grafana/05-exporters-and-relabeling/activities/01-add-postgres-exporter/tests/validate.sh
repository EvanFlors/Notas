#!/usr/bin/env bash
# Validate obs-05-01: postgres_exporter wired, pg_up == 1, relabel applied, system dbs dropped.
#
# Note: we deliberately do NOT enable `set -o pipefail` because we pipe curl output through
# `grep -q` and friends; a successful early match in grep makes curl receive SIGPIPE (141)
# which pipefail would spuriously surface as a failure.
set -eu

PROM_URL="${PROM_URL:-http://localhost:9090}"
SCRATCH="${SCRATCH:-/tmp/obs-05-01-validate}"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

passed=0
failed=0
report=""

skip_if_down() {
  if ! curl -fsS --max-time 3 "$PROM_URL/-/ready" >/dev/null 2>&1; then
    echo "SKIP: Prometheus not reachable at $PROM_URL (stack not running?)."
    echo "      This is a graceful skip; run 'docker compose up -d' in starter/ and retry."
    exit 0
  fi
}

query() {
  local q="$1"
  curl -fsS --data-urlencode "query=$q" "$PROM_URL/api/v1/query" > "$SCRATCH/resp.json"
}

json_num_results() {
  # Count how many entries are in data.result[]. Avoid jq dependency: use grep.
  grep -o '"value"' "$SCRATCH/resp.json" | wc -l | tr -d ' '
}

check_pg_up() {
  local name="pg_up == 1"
  query 'pg_up'
  if grep -q '"1"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (pg_up not 1; is postgres-exporter running?)\n"
    failed=$((failed+1))
  fi
}

check_instance_label() {
  local name="instance=pg-main label applied via relabel"
  query 'up{job="postgres",instance="pg-main"}'
  local n
  n="$(json_num_results)"
  if [ "$n" -ge 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (no series with instance=pg-main; relabel missing?)\n"
    failed=$((failed+1))
  fi
}

check_env_team_labels() {
  local name="env=lab AND team=data labels present"
  query 'up{job="postgres",env="lab",team="data"}'
  local n
  n="$(json_num_results)"
  if [ "$n" -ge 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (env/team labels not found on postgres job)\n"
    failed=$((failed+1))
  fi
}

check_at_least_3_pg_series() {
  local name="at least 3 pg_stat_database_* series survived"
  query 'count({__name__=~"pg_stat_database_.+"})'
  if grep -qE '"[3-9][0-9]*"|"[1-9][0-9]+"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (fewer than 3 pg_stat_database_* series)\n"
    failed=$((failed+1))
  fi
}

check_system_dbs_dropped() {
  local name="system dbs (template0/template1/postgres) dropped from pg_stat_database_*"
  query 'count(pg_stat_database_xact_commit{datname=~"template0|template1|postgres"})'
  # Expect 0 results or value "0". The query returns no result when count is empty;
  # if the series exists with value "0", we also accept.
  local n
  n="$(json_num_results)"
  if [ "$n" -eq 0 ] || grep -q '"0"' "$SCRATCH/resp.json"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (system db series still present; metric_relabel_configs missing?)\n"
    failed=$((failed+1))
  fi
}

echo "== obs-05-01 validate =="
skip_if_down
check_pg_up
check_instance_label
check_env_team_labels
check_at_least_3_pg_series
check_system_dbs_dropped

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
