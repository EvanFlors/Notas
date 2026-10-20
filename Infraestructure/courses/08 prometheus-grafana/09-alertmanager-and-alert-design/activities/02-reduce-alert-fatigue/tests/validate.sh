#!/usr/bin/env bash
# Validate obs-09-02-reduce-alert-fatigue.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Checks: alerts.yaml with EXACTLY 5 alerts, mandatory fields on each, WHY.md
# structure, and promtool check rules if available.
#
# Usage: bash tests/validate.sh [BASE_DIR]   (default: /tmp/obs-09-02)

BASE="${1:-/tmp/obs-09-02}"
fail=0
skip=0

echo "== Validating $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Did you copy the starter?"
  exit 1
fi

ALERTS="$BASE/alerts.yaml"
WHY="$BASE/WHY.md"

# -------- 1. Files present --------
if [ -f "$ALERTS" ]; then
  echo "  OK   alerts.yaml present"
else
  echo "  FAIL alerts.yaml missing"
  fail=$((fail+1))
fi
if [ -f "$WHY" ]; then
  echo "  OK   WHY.md present"
else
  echo "  FAIL WHY.md missing"
  fail=$((fail+1))
fi

# -------- 2. Exactly 5 alerts --------
if [ -f "$ALERTS" ]; then
  n=$(grep -c '^\s*- alert:' "$ALERTS")
  if [ "${n:-0}" -eq 5 ]; then
    echo "  OK   exactly 5 alerts defined"
  else
    echo "  FAIL expected 5 alerts, found ${n:-0}"
    fail=$((fail+1))
  fi

  # -------- 3. Mandatory fields: each >= 5 occurrences --------
  for field in "for:" "severity:" "team:" "summary:" "description:" "runbook_url:"; do
    cnt=$(grep -c "$field" "$ALERTS")
    if [ "${cnt:-0}" -ge 5 ]; then
      echo "  OK   field '$field' present (>=5 occurrences)"
    else
      echo "  FAIL field '$field' <5 occurrences (found $cnt)"
      fail=$((fail+1))
    fi
  done
fi

# -------- 4. WHY.md structure --------
if [ -f "$WHY" ]; then
  if grep -qi '^##.*Mantenidas' "$WHY"; then
    echo "  OK   WHY.md has 'Mantenidas' section"
  else
    echo "  FAIL WHY.md missing 'Mantenidas' section"
    fail=$((fail+1))
  fi
  if grep -qi '^##.*Eliminadas' "$WHY"; then
    echo "  OK   WHY.md has 'Eliminadas' section"
  else
    echo "  FAIL WHY.md missing 'Eliminadas' section"
    fail=$((fail+1))
  fi
  bullets=$(grep -c '^- ' "$WHY")
  if [ "${bullets:-0}" -ge 15 ]; then
    echo "  OK   WHY.md has >=15 bullets ($bullets)"
  else
    echo "  FAIL WHY.md needs >=15 bullets (found $bullets)"
    fail=$((fail+1))
  fi
fi

# -------- 5. promtool check --------
PROMTOOL=""
if command -v promtool >/dev/null 2>&1; then
  PROMTOOL="promtool"
elif command -v docker >/dev/null 2>&1; then
  PROMTOOL="docker run --rm --entrypoint promtool -v $BASE:/w -w /w prom/prometheus:latest"
fi

if [ -z "$PROMTOOL" ]; then
  echo "  SKIP promtool not available (nor docker)"
  skip=$((skip+1))
else
  if [ -f "$ALERTS" ] && $PROMTOOL check rules alerts.yaml >/tmp/obs-09-02-check.log 2>&1; then
    echo "  OK   promtool check rules"
  else
    echo "  FAIL promtool check rules (see /tmp/obs-09-02-check.log)"
    fail=$((fail+1))
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "== PASS == ($skip skipped)"
  exit 0
else
  echo "== FAIL == $fail failure(s), $skip skipped"
  exit 1
fi
