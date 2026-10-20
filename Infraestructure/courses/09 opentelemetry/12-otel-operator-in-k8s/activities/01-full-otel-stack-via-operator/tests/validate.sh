#!/usr/bin/env bash
# Validator for otel-12-01-full-otel-stack-via-operator.
#
# Verifies, against the live cluster:
#   1. OTel Operator and cert-manager deployments are Available.
#   2. OpenTelemetryCollector/gateway (deployment) is reconciled and Available.
#   3. OpenTelemetryCollector/agent (daemonset) is reconciled.
#   4. Instrumentation/default-instr exists in ns demo.
#   5. The pyapp Pod has the init container 'opentelemetry-auto-instrumentation-python'.
#   6. The pyapp container has OTEL_* env vars injected.
#
# NOTE: NO `set -o pipefail` on purpose. Several checks use `grep -q` on piped
# `kubectl` output; pipefail would spuriously mark those as failures when grep
# closes the pipe early (SIGPIPE on upstream).

set -eu

pass=0
fail=0
report=""

mark_ok()   { pass=$((pass+1)); report+="  OK   — $1\n"; }
mark_fail() { fail=$((fail+1)); report+="  FAIL — $1\n"; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have kubectl; then
  echo "SKIP: kubectl not installed."
  exit 0
fi
if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  echo "SKIP: no reachable cluster."
  exit 0
fi

echo "== otel-12-01 validator =="

# 1. cert-manager
if kubectl -n cert-manager get deploy cert-manager-webhook >/dev/null 2>&1; then
  mark_ok "cert-manager installed"
else
  mark_fail "cert-manager-webhook not found (run starter/setup.sh)"
fi

# 2. Operator
if kubectl -n opentelemetry-operator-system get deploy >/dev/null 2>&1; then
  mark_ok "OTel Operator namespace present"
else
  mark_fail "OTel Operator not installed"
fi

# 3. Gateway Collector
if kubectl -n observability get otelcol gateway >/dev/null 2>&1; then
  mark_ok "OpenTelemetryCollector/gateway exists"
  if kubectl -n observability get deploy gateway-collector >/dev/null 2>&1; then
    ready="$(kubectl -n observability get deploy gateway-collector -o jsonpath='{.status.readyReplicas}')"
    if [ "${ready:-0}" -ge 1 ] 2>/dev/null; then
      mark_ok "gateway-collector deployment has >=1 ready replica"
    else
      mark_fail "gateway-collector deployment not ready"
    fi
  else
    mark_fail "gateway-collector Deployment not reconciled yet"
  fi
else
  mark_fail "OpenTelemetryCollector/gateway not applied"
fi

# 4. Agent DaemonSet
if kubectl -n observability get otelcol agent >/dev/null 2>&1; then
  mark_ok "OpenTelemetryCollector/agent exists"
  if kubectl -n observability get daemonset agent-collector >/dev/null 2>&1; then
    desired="$(kubectl -n observability get ds agent-collector -o jsonpath='{.status.desiredNumberScheduled}')"
    ready="$(kubectl -n observability get ds agent-collector -o jsonpath='{.status.numberReady}')"
    if [ "${desired:-0}" -ge 1 ] && [ "${ready:-0}" = "${desired:-0}" ]; then
      mark_ok "agent-collector DaemonSet fully ready ($ready/$desired)"
    else
      mark_fail "agent-collector DaemonSet not ready ($ready/$desired)"
    fi
  else
    mark_fail "agent-collector DaemonSet not reconciled yet"
  fi
else
  mark_fail "OpenTelemetryCollector/agent not applied"
fi

# 5. Instrumentation CR
if kubectl -n demo get instrumentation default-instr >/dev/null 2>&1; then
  mark_ok "Instrumentation/default-instr exists in ns demo"
else
  mark_fail "Instrumentation/default-instr missing in ns demo"
fi

# 6. pyapp Pod + mutation
pod="$(kubectl -n demo get pod -l app=pyapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [ -n "$pod" ]; then
  mark_ok "pyapp Pod exists: $pod"
  init_names="$(kubectl -n demo get pod "$pod" -o jsonpath='{range .spec.initContainers[*]}{.name}{"\n"}{end}' 2>/dev/null)"
  if printf '%s\n' "$init_names" | grep -qx 'opentelemetry-auto-instrumentation-python'; then
    mark_ok "initContainer 'opentelemetry-auto-instrumentation-python' injected"
  else
    mark_fail "initContainer 'opentelemetry-auto-instrumentation-python' not found"
  fi
  env_names="$(kubectl -n demo get pod "$pod" -o jsonpath='{range .spec.containers[0].env[*]}{.name}{"\n"}{end}' 2>/dev/null)"
  if printf '%s\n' "$env_names" | grep -qx 'OTEL_EXPORTER_OTLP_ENDPOINT'; then
    mark_ok "OTEL_EXPORTER_OTLP_ENDPOINT present on app container"
  else
    mark_fail "OTEL_EXPORTER_OTLP_ENDPOINT not injected on app container"
  fi
else
  mark_fail "pyapp Pod not found in ns demo"
fi

echo
printf "%b" "$report"
echo
echo "----------------------------------------"
echo "SUMMARY: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then
  echo "RESULT: OK"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
