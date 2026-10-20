#!/usr/bin/env bash
# Validator for otel-12-02-upgrade-collector-cr.
#
# Two modes:
#   A: cluster reachable + CR upgradable present → check image >= 0.111.x,
#      check config contains a processor added by the student (name starts
#      with "attributes") AND check ADR is complete.
#   B: no cluster → check ADR has the 4 sections with content.
#
# NOTE: NO `set -o pipefail` on purpose (grep -q on pipes).

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$(cd "$HERE/.." && pwd)/starter"
ADR="$STARTER/OPERATOR_VS_HELM.md"

have() { command -v "$1" >/dev/null 2>&1; }

pass=0
fail=0
report=""
mark_ok()   { pass=$((pass+1)); report+="  OK   — $1\n"; }
mark_fail() { fail=$((fail+1)); report+="  FAIL — $1\n"; }

check_adr() {
  if [ ! -f "$ADR" ]; then
    mark_fail "OPERATOR_VS_HELM.md missing"
    return
  fi
  local body
  body="$(cat "$ADR")"
  for section in "## 1. Contexto" "## 2. Decisión" "## 3. Justificación" "## 4. Equivalencias y red flags"; do
    if printf '%s\n' "$body" | grep -qF "$section"; then
      mark_ok "ADR section present: '$section'"
    else
      mark_fail "ADR section missing: '$section'"
    fi
  done
  # Student must remove the TODO-STUDENT sentinel after completing the ADR.
  if grep -q 'TODO-STUDENT' "$ADR"; then
    mark_fail "ADR still contains the TODO-STUDENT sentinel — the template was not completed"
  else
    mark_ok "ADR TODO-STUDENT sentinel removed"
  fi
  local lines
  lines="$(wc -l < "$ADR" | tr -d ' ')"
  if [ "${lines:-0}" -gt 25 ]; then
    mark_ok "ADR has non-trivial content ($lines lines)"
  else
    mark_fail "ADR has too little content ($lines lines)"
  fi
}

try_mode_a() {
  have kubectl || return 1
  kubectl version --request-timeout=3s >/dev/null 2>&1 || return 1
  kubectl -n observability get otelcol upgradable >/dev/null 2>&1 || return 1

  echo "== mode A: cluster + CR 'upgradable' detected =="
  local img
  img="$(kubectl -n observability get otelcol upgradable -o jsonpath='{.spec.image}')"
  echo "   current spec.image: ${img:-<empty>}"
  if [ -z "$img" ]; then
    mark_fail "spec.image is empty — should be pinned after the upgrade exercise"
  else
    # Accept 0.111.x or newer (minor >= 111) as valid upgrade.
    local minor
    minor="$(printf '%s' "$img" | sed -n 's/.*:0\.\([0-9][0-9]*\)\..*/\1/p')"
    if [ -n "$minor" ] && [ "$minor" -ge 111 ] 2>/dev/null; then
      mark_ok "spec.image upgraded (minor $minor >= 111)"
    else
      mark_fail "spec.image not upgraded (got '$img', expected minor >= 0.111)"
    fi
  fi

  # Config contains a processor whose name starts with "attributes" (added by student).
  local proc_names
  proc_names="$(kubectl -n observability get otelcol upgradable -o jsonpath='{.spec.config.processors}' 2>/dev/null || true)"
  if printf '%s' "$proc_names" | grep -q 'attributes'; then
    mark_ok "config contains an 'attributes' processor"
  else
    mark_fail "config does not contain an 'attributes' processor"
  fi

  # Deployment rolled: look for >1 ReplicaSet owned by it.
  local rs_count
  rs_count="$(kubectl -n observability get rs -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].name=="upgradable-collector")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${rs_count:-0}" -ge 2 ]; then
    mark_ok "deployment has rolled at least once ($rs_count ReplicaSets)"
  else
    mark_fail "no evidence of a rollout (only $rs_count ReplicaSet)"
  fi

  check_adr
  return 0
}

echo "== otel-12-02 validator =="

if try_mode_a; then
  mode="A"
else
  if ! have kubectl; then
    echo "== mode B: kubectl not installed → documentation-only check =="
  else
    echo "== mode B: no reachable cluster or CR → documentation-only check =="
  fi
  mode="B"
  check_adr
fi

echo
printf "%b" "$report"
echo
echo "----------------------------------------"
echo "SUMMARY: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then
  echo "RESULT: OK (mode: $mode)"
  exit 0
else
  echo "RESULT: FAIL (mode: $mode)"
  exit 1
fi
