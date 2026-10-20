#!/usr/bin/env bash
# Validate argo-11-02-recover-argocd-from-backup.
# Compares post-restore state to the pre-disaster snapshot.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks use `grep -q`
# where early-match SIGPIPE would be reported as spurious failures.

BASE="${BASE:-/tmp/argo-11-02}"
SNAP="$BASE/pre-disaster.apps"
RUNBOOK="$BASE/work/RUNBOOK.md"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating argo-11-02-recover-argocd-from-backup =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl not installed" >&2; exit 1
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: no active kube context" >&2; exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required" >&2; exit 1
fi

# ---- Check 1: ns argocd exists and server is Available ----
if kubectl get ns argocd >/dev/null 2>&1; then
  avail="$(kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo '')"
  if [ "$avail" = "True" ]; then
    note_ok "ns argocd present and argocd-server Available"
  else
    note_fail "argocd-server not Available (status: '$avail')"
  fi
else
  note_fail "namespace 'argocd' does not exist (restore not completed)"
fi

# ---- Check 2: pre-disaster snapshot exists and all apps are back ----
if [ ! -f "$SNAP" ]; then
  note_fail "pre-disaster snapshot missing at $SNAP — did you run bootstrap.sh?"
else
  missing=""
  while IFS= read -r app; do
    [ -z "$app" ] && continue
    if ! kubectl -n argocd get application "$app" >/dev/null 2>&1; then
      missing+="$app "
    fi
  done < "$SNAP"
  if [ -z "$missing" ]; then
    note_ok "All pre-disaster Applications present after restore"
  else
    note_fail "Missing after restore: $missing"
  fi
fi

# ---- Check 3: all current Applications Synced + Healthy ----
apps_json="$(kubectl -n argocd get applications -o json 2>/dev/null || echo '{"items":[]}')"
bad="$(printf '%s' "$apps_json" | jq -r '.items[] | select(.status.sync.status != "Synced" or .status.health.status != "Healthy") | .metadata.name')"
if [ -z "$bad" ]; then
  note_ok "All Applications Synced + Healthy"
else
  note_fail "Not Synced/Healthy: $(printf '%s' "$bad" | tr '\n' ' ')"
fi

# ---- Check 4: RUNBOOK.md exists and non-trivial ----
if [ -f "$RUNBOOK" ]; then
  words="$(wc -w < "$RUNBOOK" | tr -d ' ')"
  if [ "${words:-0}" -ge 40 ]; then
    note_ok "RUNBOOK.md present with $words words"
  else
    note_fail "RUNBOOK.md too short ($words words; need >= 40)"
  fi
else
  note_fail "RUNBOOK.md missing at $RUNBOOK"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total controles OK (requeridos: 4)."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
