#!/usr/bin/env bash
# Validate cap-08-01-kind-apply-and-smoke.
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks usan
# `cmd | grep -q ...` y pipefail reportaria SIGPIPE (141) espurio
# cuando grep sale al primer match.
set -eu

STAGE_DIR="${STAGE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
fail=0

note_ok()   { echo "  OK   -- $1"; }
note_fail() { echo "  FAIL -- $1"; fail=$((fail+1)); }

echo "== Validating cap-08-01-kind-apply-and-smoke (stage=$STAGE_DIR) =="

for env in dev staging prod; do
  if command -v kubectl >/dev/null 2>&1; then
    if kubectl kustomize "$STAGE_DIR/k8s/overlays/$env" >/dev/null 2>&1; then
      note_ok "kubectl kustomize overlay=$env"
    else
      note_fail "kubectl kustomize overlay=$env"
    fi
  elif command -v kustomize >/dev/null 2>&1; then
    if kustomize build "$STAGE_DIR/k8s/overlays/$env" >/dev/null 2>&1; then
      note_ok "kustomize build overlay=$env"
    else
      note_fail "kustomize build overlay=$env"
    fi
  else
    note_fail "ni kubectl ni kustomize disponibles para overlay=$env"
  fi
done

# Si hay cluster activo, verifica el rollout.
if command -v kubectl >/dev/null 2>&1 && kubectl version --request-timeout=3s >/dev/null 2>&1; then
  avail="$(kubectl -n app-dev get deploy capstone-api -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo '')"
  if [ "$avail" = "True" ]; then
    note_ok "deploy app-dev/capstone-api Available"
  else
    echo "  SKIP -- cluster activo pero deploy aun no Available (ok si no aplicaste)"
  fi
else
  echo "  SKIP -- sin cluster activo, se omiten checks runtime"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s)."
exit 0
