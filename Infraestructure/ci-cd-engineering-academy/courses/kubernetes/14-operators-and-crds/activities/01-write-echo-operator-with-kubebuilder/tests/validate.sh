#!/usr/bin/env bash
# Validator for k8s-14-01-write-echo-operator-with-kubebuilder.
#
# Two modes:
#   A: student implemented the operator with Kubebuilder; a kind cluster is up,
#      a sample Echo CR exists, and the ConfigMap <echo>-echo mirrors its message.
#   B: student completed starter/EVALUATION.md with CRD YAML + Reconcile pseudocode.
#
# The script tries mode A first; if there is no cluster or no kubectl, falls back
# to mode B.
#
# Note: NO `set -o pipefail` on purpose — several checks use `grep -q` on piped
# input, which can SIGPIPE the upstream command and spuriously fail with pipefail.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$(cd "$HERE/.." && pwd)/starter"
EVAL_FILE="$STARTER/EVALUATION.md"

have() { command -v "$1" >/dev/null 2>&1; }

pass=0
fail=0
report=""

mark_ok()   { pass=$((pass+1)); report+="  OK   — $1\n"; }
mark_fail() { fail=$((fail+1)); report+="  FAIL — $1\n"; }

try_mode_a() {
  # Mode A requires: kubectl, a reachable cluster, CRD installed, an Echo CR,
  # and a ConfigMap mirroring its message.
  have kubectl || return 1
  kubectl version --request-timeout=3s >/dev/null 2>&1 || return 1
  kubectl get crd echoes.demo.academy.io >/dev/null 2>&1 || return 1

  echo "== mode A: cluster + CRD detected =="
  local echoes
  echoes="$(kubectl get echoes --all-namespaces --no-headers 2>/dev/null || true)"
  if [ -z "$echoes" ]; then
    mark_fail "no Echo CRs exist (apply config/samples/demo_v1alpha1_echo.yaml)"
    return 0
  fi
  mark_ok "found Echo CR(s)"

  # Pick first Echo (ns + name + message)
  local ns name msg cm_name observed cm_msg
  ns="$(echo "$echoes" | awk 'NR==1{print $1}')"
  name="$(echo "$echoes" | awk 'NR==1{print $2}')"
  msg="$(kubectl -n "$ns" get echo "$name" -o jsonpath='{.spec.message}' 2>/dev/null || echo '')"
  cm_name="${name}-echo"

  if kubectl -n "$ns" get configmap "$cm_name" >/dev/null 2>&1; then
    mark_ok "ConfigMap $ns/$cm_name exists"
  else
    mark_fail "ConfigMap $ns/$cm_name missing (controller not reconciling?)"
    return 0
  fi

  cm_msg="$(kubectl -n "$ns" get configmap "$cm_name" -o jsonpath='{.data.message}' 2>/dev/null || echo '')"
  if [ "$cm_msg" = "$msg" ] && [ -n "$msg" ]; then
    mark_ok "ConfigMap.data.message == Echo.spec.message ('$msg')"
  else
    mark_fail "ConfigMap.data.message ('$cm_msg') != Echo.spec.message ('$msg')"
  fi

  # ownerReferences check
  local owner_kind
  owner_kind="$(kubectl -n "$ns" get configmap "$cm_name" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || echo '')"
  if [ "$owner_kind" = "Echo" ]; then
    mark_ok "ConfigMap has ownerReference to Echo"
  else
    mark_fail "ConfigMap ownerReferences missing or wrong kind ('$owner_kind')"
  fi

  # status subresource populated
  observed="$(kubectl -n "$ns" get echo "$name" -o jsonpath='{.status.observedMessage}' 2>/dev/null || echo '')"
  if [ "$observed" = "$msg" ]; then
    mark_ok "status.observedMessage populated via /status"
  else
    mark_fail "status.observedMessage ('$observed') not set — did you call r.Status().Update()?"
  fi

  return 0
}

try_mode_b() {
  echo "== mode B: documentation-only =="
  if [ ! -f "$EVAL_FILE" ]; then
    mark_fail "starter/EVALUATION.md missing"
    return 0
  fi
  mark_ok "EVALUATION.md present"

  # Must contain a YAML block that looks like a CRD (apiextensions + Echo).
  local has_apiext has_echo_kind has_subresource has_pseudocode
  if grep -q 'apiextensions.k8s.io' "$EVAL_FILE"; then has_apiext=1; else has_apiext=0; fi
  if grep -q 'kind: CustomResourceDefinition' "$EVAL_FILE"; then has_echo_kind=1; else has_echo_kind=0; fi
  if grep -q 'subresources:' "$EVAL_FILE"; then has_subresource=1; else has_subresource=0; fi

  if [ "$has_apiext" -eq 1 ] && [ "$has_echo_kind" -eq 1 ] && [ "$has_subresource" -eq 1 ]; then
    mark_ok "CRD YAML present (apiextensions + kind + subresources)"
  else
    mark_fail "CRD YAML incomplete (apiext=$has_apiext kind=$has_echo_kind subresources=$has_subresource)"
  fi

  # Must contain pseudocode mentioning key steps.
  local pc_fetch pc_cm pc_owner pc_status
  if grep -qi 'reconcile' "$EVAL_FILE";              then pc_fetch=1;  else pc_fetch=0;  fi
  if grep -qi 'configmap' "$EVAL_FILE";              then pc_cm=1;     else pc_cm=0;     fi
  if grep -qi 'ownerreference\|setcontrollerreference' "$EVAL_FILE"; then pc_owner=1; else pc_owner=0; fi
  if grep -qi 'status\(\)\.update\|statusupdate\|/status' "$EVAL_FILE"; then pc_status=1; else pc_status=0; fi

  if [ "$pc_fetch" -eq 1 ] && [ "$pc_cm" -eq 1 ] && [ "$pc_owner" -eq 1 ] && [ "$pc_status" -eq 1 ]; then
    mark_ok "pseudocode covers Reconcile + ConfigMap + ownerRef + status subresource"
  else
    mark_fail "pseudocode missing elements (reconcile=$pc_fetch cm=$pc_cm owner=$pc_owner status=$pc_status)"
  fi

  # No TODO (student) markers should remain.
  local todo_count
  todo_count="$(grep -c 'TODO (student)' "$EVAL_FILE" || true)"
  if [ "$todo_count" -eq 0 ]; then
    mark_ok "no 'TODO (student)' markers left"
  else
    mark_fail "$todo_count 'TODO (student)' markers still in EVALUATION.md"
  fi

  return 0
}

MODE=""
if try_mode_a; then
  MODE="A"
else
  try_mode_b
  MODE="B"
fi

echo
printf "%b" "$report"
echo
total=$((pass+fail))
if [ "$fail" -eq 0 ] && [ "$total" -gt 0 ]; then
  echo "RESULT: OK (mode: $MODE)  checks: $pass/$total"
  exit 0
else
  echo "RESULT: FAIL (mode: $MODE)  checks: $pass/$total"
  exit 1
fi
