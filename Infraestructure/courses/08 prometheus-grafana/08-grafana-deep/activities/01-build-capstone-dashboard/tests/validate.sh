#!/usr/bin/env bash
# Validate obs-08-01: dashboard JSON must have 6 panel types + 2 variables (query + custom).
# Also, if Grafana is up at :3000, verify the dashboard is reachable with the Provisioned flag.
#
# Note: no `set -o pipefail` to avoid SIGPIPE false positives when `grep -q` closes
# a pipe early on upstream commands (jq / curl).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DASHBOARD="${1:-$ROOT/starter/grafana/dashboards/red.json}"

passed=0
failed=0
skipped=0
report=""

ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }
skip() { report+="  SKIP $1\n"; skipped=$((skipped+1)); }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required; install it and retry." >&2
  exit 2
fi

if [ ! -f "$DASHBOARD" ]; then
  echo "FAIL: dashboard JSON not found at $DASHBOARD" >&2
  exit 1
fi

echo "== Static JSON checks against $DASHBOARD =="

# uid fijo
uid="$(jq -r '.uid // ""' "$DASHBOARD")"
if [ -n "$uid" ] && [ "$uid" != "null" ]; then
  ok "dashboard uid is set ('$uid')"
else
  fail "dashboard uid is missing"
fi

# panel types
for t in timeseries stat gauge heatmap table state-timeline; do
  count="$(jq --arg t "$t" '[.panels[] | select(.type==$t)] | length' "$DASHBOARD")"
  if [ "${count:-0}" -ge 1 ]; then
    ok "panel of type '$t' present ($count)"
  else
    fail "missing panel of type '$t'"
  fi
done

# variables
var_query="$(jq '[.templating.list[]? | select(.type=="query")] | length' "$DASHBOARD")"
var_custom="$(jq '[.templating.list[]? | select(.type=="custom")] | length' "$DASHBOARD")"
if [ "${var_query:-0}" -ge 1 ]; then
  ok "variable of type 'query' present"
else
  fail "missing variable of type 'query'"
fi
if [ "${var_custom:-0}" -ge 1 ]; then
  ok "variable of type 'custom' present"
else
  fail "missing variable of type 'custom'"
fi

# legend formatting
legend_count="$(jq '[.panels[].targets[]? | select(.legendFormat // "" | contains("{{"))] | length' "$DASHBOARD")"
if [ "${legend_count:-0}" -ge 1 ]; then
  ok "at least one panel uses legendFormat with {{...}}"
else
  fail "no panel uses legendFormat with {{...}}"
fi

# $__rate_interval o $interval usage
rate_hits="$(jq -r '.panels[].targets[]?.expr // ""' "$DASHBOARD" | grep -c '\$__rate_interval\|\$interval' || true)"
if [ "${rate_hits:-0}" -ge 1 ]; then
  ok "at least one query uses \$__rate_interval or \$interval"
else
  fail "no query uses \$__rate_interval or \$interval"
fi

echo
echo "== Runtime checks (Grafana at http://localhost:3000) =="

if ! command -v curl >/dev/null 2>&1; then
  skip "curl not installed; skipping runtime checks"
else
  if curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:3000/api/health | grep -q '^200$'; then
    body="$(curl -s --max-time 5 -u admin:admin "http://localhost:3000/api/dashboards/uid/$uid" || true)"
    if [ -n "$body" ] && echo "$body" | jq -e '.dashboard.uid' >/dev/null 2>&1; then
      ok "dashboard uid '$uid' is published in Grafana"
      prov="$(echo "$body" | jq -r '.meta.provisioned // false')"
      if [ "$prov" = "true" ]; then
        ok "dashboard is marked as provisioned"
      else
        fail "dashboard is NOT marked as provisioned"
      fi
    else
      fail "dashboard '$uid' is not reachable via Grafana API"
    fi
  else
    skip "Grafana not responding on :3000 (did you 'docker compose up -d'?)"
  fi
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed+skipped))
echo "RESULT: $passed/$total checks OK ($failed failed, $skipped skipped)."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
