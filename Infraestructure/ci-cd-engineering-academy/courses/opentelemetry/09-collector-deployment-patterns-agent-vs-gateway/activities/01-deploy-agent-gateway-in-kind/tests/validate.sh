#!/usr/bin/env bash
# Validate otel-09-01: 5 checks (ns, gateway, agent, service, telemetry).
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks hacen
# `kubectl ... | grep -q ...` y pipefail reportaria SIGPIPE (141) espurio
# cuando grep sale al primer match.

NS="${NS:-observability}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating otel-09-01 (ns=$NS) =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no instalado"; exit 0
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: kubectl no puede alcanzar apiserver"; exit 0
fi

# ---- Check 1: namespace existe ----
if kubectl get ns "$NS" >/dev/null 2>&1; then
  note_ok "Namespace '$NS' existe"
else
  note_fail "Namespace '$NS' no existe"
fi

# ---- Check 2: gateway Deployment Available ----
avail="$(kubectl -n "$NS" get deploy otel-gateway -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo '')"
if [ "$avail" = "True" ]; then
  note_ok "Deployment otel-gateway Available=True"
else
  note_fail "Deployment otel-gateway no Available (status='$avail')"
fi

# ---- Check 3: agent DaemonSet con todos los pods ready ----
desired="$(kubectl -n "$NS" get ds otel-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
ready="$(kubectl -n "$NS" get ds otel-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [ "$desired" != "0" ] && [ "$desired" = "$ready" ]; then
  note_ok "DaemonSet otel-agent ready=$ready/$desired"
else
  note_fail "DaemonSet otel-agent ready=$ready/$desired (esperado iguales y > 0)"
fi

# ---- Check 4: Service otel-gateway con endpoints no vacios ----
eps="$(kubectl -n "$NS" get endpoints otel-gateway -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo '')"
if [ -n "$eps" ]; then
  note_ok "Service otel-gateway tiene endpoints: $eps"
else
  note_fail "Service otel-gateway sin endpoints (selector no matchea?)"
fi

# ---- Check 5: gateway log muestra ResourceSpans (requiere haber corrido send-traces.sh) ----
spans="$(kubectl -n "$NS" logs deploy/otel-gateway --tail=500 2>/dev/null | grep -c 'ResourceSpans' || true)"
if [ "${spans:-0}" -gt 0 ]; then
  note_ok "Gateway log contiene $spans batch(es) ResourceSpans"
else
  note_fail "Gateway log no muestra ResourceSpans (ejecuta tests/send-traces.sh primero)"
fi

echo
echo "---- report ----"
printf "%b" "$report"
echo "passed=$passed  failed=$failed"
if [ "$failed" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
fi
exit 1
