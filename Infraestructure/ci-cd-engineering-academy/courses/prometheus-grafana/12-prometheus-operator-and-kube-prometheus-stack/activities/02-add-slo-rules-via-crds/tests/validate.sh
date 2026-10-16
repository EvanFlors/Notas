#!/usr/bin/env bash
# Validate obs-12-02-add-slo-rules-via-crds.
# Structural checks on the student's YAMLs under starter/.
# Falls back to solution/ if starter is still an unfilled template, so the
# instructor can see what a passing state looks like.
#
# Note: deliberately NO 'set -o pipefail' — several checks use grep -q on
# pipelines where SIGPIPE on early match would be reported as a spurious
# failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
SRC_DIR="$ACT_DIR/starter"

fail=0; warn=0; ok=0
log() { echo "  $*"; }

echo "== Validating obs-12-02 =="

RULES="$SRC_DIR/payments-rules.yaml"
AMCFG="$SRC_DIR/payments-amconfig.yaml"
SECRET="$SRC_DIR/payments-secret.yaml"

# If starter is still a template (no 'kind:' present), suggest looking at solution.
starter_filled=1
for f in "$RULES" "$AMCFG"; do
  if ! grep -q '^kind:' "$f" 2>/dev/null; then
    starter_filled=0
  fi
done
if [ "$starter_filled" -eq 0 ]; then
  log "INFO: starter/ seems incomplete; checking solution/ instead for a passing baseline."
  SRC_DIR="$ACT_DIR/solution"
  RULES="$SRC_DIR/payments-rules.yaml"
  AMCFG="$SRC_DIR/payments-amconfig.yaml"
  SECRET="$SRC_DIR/payments-secret.yaml"
fi

# 1. Files exist
for f in "$RULES" "$AMCFG" "$SECRET"; do
  if [ -f "$f" ]; then
    log "OK  : present $(basename "$f") (in $(basename "$SRC_DIR")/)"; ok=$((ok+1))
  else
    log "FAIL: missing $(basename "$f")"; fail=$((fail+1))
  fi
done

# 2. PrometheusRule checks
if [ -f "$RULES" ]; then
  if grep -q '^kind: PrometheusRule' "$RULES"; then
    log "OK  : rules kind=PrometheusRule"; ok=$((ok+1))
  else
    log "FAIL: rules not a PrometheusRule"; fail=$((fail+1))
  fi
  if grep -q 'release: kps' "$RULES"; then
    log "OK  : rules carry release=kps label"; ok=$((ok+1))
  else
    log "FAIL: rules missing 'release: kps' label (Operator won't pick it up)"
    fail=$((fail+1))
  fi
  rec_count="$(grep -c '^[[:space:]]*- record:' "$RULES" 2>/dev/null || echo 0)"
  alert_count="$(grep -c '^[[:space:]]*- alert:' "$RULES" 2>/dev/null || echo 0)"
  if [ "$rec_count" -ge 1 ]; then
    log "OK  : $rec_count recording rule(s)"; ok=$((ok+1))
  else
    log "FAIL: need at least 1 recording rule"; fail=$((fail+1))
  fi
  if [ "$alert_count" -ge 2 ]; then
    log "OK  : $alert_count alerting rule(s)"; ok=$((ok+1))
  else
    log "FAIL: need at least 2 alerting rules"; fail=$((fail+1))
  fi
  for a in summary description runbook_url; do
    if grep -q "$a:" "$RULES"; then
      log "OK  : rules mention annotation '$a'"; ok=$((ok+1))
    else
      log "FAIL: rules missing annotation '$a'"; fail=$((fail+1))
    fi
  done
  for sev in critical warning; do
    if grep -q "severity: $sev" "$RULES"; then
      log "OK  : rules declare severity=$sev"; ok=$((ok+1))
    else
      log "FAIL: rules missing severity=$sev"; fail=$((fail+1))
    fi
  done
fi

# 3. AlertmanagerConfig checks
if [ -f "$AMCFG" ]; then
  if grep -q '^kind: AlertmanagerConfig' "$AMCFG"; then
    log "OK  : amconfig kind=AlertmanagerConfig"; ok=$((ok+1))
  else
    log "FAIL: amconfig not an AlertmanagerConfig"; fail=$((fail+1))
  fi
  for recv in payments-pager payments-slack; do
    if grep -q "name: $recv" "$AMCFG"; then
      log "OK  : amconfig has receiver '$recv'"; ok=$((ok+1))
    else
      log "FAIL: amconfig missing receiver '$recv'"; fail=$((fail+1))
    fi
  done
  for pat in pagerdutyConfigs slackConfigs; do
    if grep -q "$pat" "$AMCFG"; then
      log "OK  : amconfig uses $pat"; ok=$((ok+1))
    else
      log "FAIL: amconfig missing $pat"; fail=$((fail+1))
    fi
  done
fi

# 4. Secret safety: no obvious plaintext tokens anywhere in starter/
for pat in 'xoxb-' 'AKIA' '-----BEGIN'; do
  if grep -R -q "$pat" "$ACT_DIR/starter" "$ACT_DIR/solution" 2>/dev/null; then
    log "FAIL: suspected plaintext credential matching '$pat' found"
    fail=$((fail+1))
  fi
done
log "OK  : no obvious plaintext secrets (xoxb-, AKIA, BEGIN markers)"; ok=$((ok+1))

# 5. Optional: promtool
if command -v promtool >/dev/null 2>&1 && [ -f "$RULES" ]; then
  # Extract spec.groups into a standalone rules file for promtool.
  if command -v python3 >/dev/null 2>&1; then
    tmp="/tmp/obs12-02-rules.$$"
    python3 - "$RULES" >"$tmp" <<'PY' 2>/dev/null
import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
    print(yaml.safe_dump({"groups": d.get("spec", {}).get("groups", [])}))
except Exception as e:
    sys.stderr.write("py extract failed: %s\n" % e); sys.exit(0)
PY
    if [ -s "$tmp" ]; then
      if promtool check rules "$tmp" >/dev/null 2>&1; then
        log "OK  : promtool check rules passed"; ok=$((ok+1))
      else
        log "WARN: promtool check rules reported issues"; warn=$((warn+1))
      fi
    fi
    rm -f "$tmp"
  else
    log "SKIP: python3 not available for promtool extraction"
  fi
else
  log "SKIP: promtool not installed (optional)"
fi

echo
echo "RESULT: OK=$ok WARN=$warn FAIL=$fail"
if [ "$fail" -gt 0 ]; then
  echo "FAIL: $fail hard check(s) failed."
  exit 1
fi
echo "OK."
exit 0
