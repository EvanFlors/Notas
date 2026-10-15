#!/usr/bin/env bash
# Validate k8s-15-02-tune-alerts-signal-vs-noise.
# Checks the structure of the edited alerts file — this activity is pure criterion,
# no cluster required.
#
# Note: deliberately NO 'set -o pipefail' — several checks use 'grep -q' where
# SIGPIPE would be reported as failure under pipefail.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"

# Accept either in-place edit of alerts.yaml or a new alerts.fixed.yaml.
CAND1="$ACT_DIR/starter/alerts.fixed.yaml"
CAND2="$ACT_DIR/starter/alerts.yaml"

TARGET=""
if [ -f "$CAND1" ]; then
  TARGET="$CAND1"
elif [ -f "$CAND2" ]; then
  TARGET="$CAND2"
else
  echo "FAIL: neither starter/alerts.fixed.yaml nor starter/alerts.yaml exists."
  exit 1
fi

echo "== Validating $TARGET =="
fail=0; ok=0; warn=0
log() { echo "  $*"; }

# 1. YAML syntax.
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$TARGET'))" 2>/dev/null; then
    log "OK  : YAML parses"; ok=$((ok+1))
  else
    log "FAIL: YAML does not parse"; fail=$((fail+1))
  fi
else
  log "WARN: python3+pyyaml not available; skipping YAML parse check"; warn=$((warn+1))
fi

# 2. Must be a PrometheusRule.
if grep -q "^kind: PrometheusRule" "$TARGET"; then
  log "OK  : kind: PrometheusRule"; ok=$((ok+1))
else
  log "FAIL: not a PrometheusRule"; fail=$((fail+1))
fi

# 3. The 3 noisy alerts must NOT survive.
#    We check by alert NAME + a distinctive fragment of the expr, together.
check_absent() { # name, expr_fragment
  local name="$1" frag="$2"
  if grep -F -q "alert: $name" "$TARGET" && grep -F -q "$frag" "$TARGET"; then
    log "FAIL: noisy alert still present: $name (expr fragment '$frag')"; fail=$((fail+1))
  else
    log "OK  : noisy alert '$name' is gone or rewritten"; ok=$((ok+1))
  fi
}

check_absent "HighCpuUsage" "rate(container_cpu_usage_seconds_total[1m]) > 0.1"
check_absent "MemoryUsage"  "container_memory_usage_bytes > 1"
check_absent "PodPresent"   "count(kube_pod_info) > 0"

# 4. The 7 healthy alerts must be preserved.
for n in KubePodCrashLooping KubeDeploymentReplicasMismatch KubeNodeNotReady KubeAPIDown KubePersistentVolumeFillingUp AlertmanagerDown PrometheusTargetScrapesFailing; do
  if grep -q "alert: $n" "$TARGET"; then
    log "OK  : healthy alert preserved: $n"; ok=$((ok+1))
  else
    log "FAIL: healthy alert missing: $n"; fail=$((fail+1))
  fi
done

# 5. At least one SLO/burn-rate rewrite present.
has_burn=0
if grep -E -q "burn_rate|BurnRate|burn-rate" "$TARGET"; then has_burn=1; fi
has_double_window=0
if grep -q "\[5m\]" "$TARGET" && grep -q "\[1h\]" "$TARGET"; then has_double_window=1; fi
if [ "$has_burn" -eq 1 ] || [ "$has_double_window" -eq 1 ]; then
  log "OK  : SLO-style burn-rate pattern detected"; ok=$((ok+1))
else
  log "FAIL: no burn-rate alert and no multi-window pattern (expected [5m] + [1h])"; fail=$((fail+1))
fi

# 6. At least one 'record:' rule exists.
if grep -q "record:" "$TARGET"; then
  log "OK  : at least one recording rule exists"; ok=$((ok+1))
else
  log "FAIL: no recording rule — expected at least one for the SLO ratio"; fail=$((fail+1))
fi

# 7. Every 'alert:' must have the three annotations.
#    We count alerts and count annotations near-ish; a cleaner check parses YAML.
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  res="$(python3 - "$TARGET" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    doc = yaml.safe_load(f)
missing = []
for g in (doc.get("spec", {}) or {}).get("groups", []) or []:
    for r in g.get("rules", []) or []:
        if "alert" in r:
            ann = r.get("annotations") or {}
            for k in ("summary", "description", "runbook_url"):
                if k not in ann:
                    missing.append(f"{r['alert']}:{k}")
print("MISSING=" + ",".join(missing))
PY
)"
  if echo "$res" | grep -q "MISSING=$"; then
    log "OK  : every alert has summary + description + runbook_url"; ok=$((ok+1))
  else
    log "FAIL: alerts missing required annotations → $res"; fail=$((fail+1))
  fi
else
  # Fallback — require that each of the three keywords appears at least as many
  # times as alerts.
  n_alerts="$(grep -c '^\s*- alert:' "$TARGET" || echo 0)"
  n_sum="$(grep -c '^\s*summary:' "$TARGET" || echo 0)"
  n_desc="$(grep -c '^\s*description:' "$TARGET" || echo 0)"
  n_rb="$(grep -c '^\s*runbook_url:' "$TARGET" || echo 0)"
  if [ "$n_sum" -ge "$n_alerts" ] && [ "$n_desc" -ge "$n_alerts" ] && [ "$n_rb" -ge "$n_alerts" ]; then
    log "OK  : (grep fallback) annotation counts ≥ alert count ($n_alerts)"; ok=$((ok+1))
  else
    log "FAIL: (grep fallback) alerts=$n_alerts sum=$n_sum desc=$n_desc rb=$n_rb"; fail=$((fail+1))
  fi
fi

echo
echo "RESULT: OK=$ok WARN=$warn FAIL=$fail"
if [ "$fail" -gt 0 ]; then
  echo "FAIL: $fail check(s) failed."
  exit 1
fi
echo "OK: alerts rewritten and structured correctly."
exit 0
