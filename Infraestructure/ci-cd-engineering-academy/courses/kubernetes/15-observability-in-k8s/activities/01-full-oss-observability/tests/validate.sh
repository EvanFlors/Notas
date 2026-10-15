#!/usr/bin/env bash
# Validate k8s-15-01-full-oss-observability.
# Structural + runtime checks. Degrades gracefully (SKIP) when kubectl/kind/helm
# are missing, or when the kind cluster isn't up.
#
# Note: deliberately NO 'set -o pipefail' — we use 'grep -q' on several
# pipelines where SIGPIPE would be reported as a spurious failure by pipefail.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
CLUSTER="${CLUSTER:-obs15}"

fail=0
warn=0
ok=0
log() { echo "  $*"; }

echo "== Validating k8s-15-01 =="

# 1. Structural: starter scripts exist and are executable.
for f in starter/bootstrap.sh starter/teardown.sh starter/kind.yaml; do
  if [ ! -f "$ACT_DIR/$f" ]; then
    log "FAIL: missing $f"; fail=$((fail+1))
  else
    log "OK  : present $f"; ok=$((ok+1))
  fi
done

if [ -f "$ACT_DIR/starter/bootstrap.sh" ] && [ -x "$ACT_DIR/starter/bootstrap.sh" ]; then
  log "OK  : starter/bootstrap.sh is executable"; ok=$((ok+1))
else
  log "WARN: starter/bootstrap.sh is not executable (chmod +x)"; warn=$((warn+1))
fi

# 2. Structural: bootstrap must reference each stack by name.
for needle in "kind create cluster" "kube-prometheus-stack" "grafana/loki" "promtail" "cert-manager" "opentelemetry-operator" "tempo"; do
  if grep -q "$needle" "$ACT_DIR/starter/bootstrap.sh" 2>/dev/null; then
    log "OK  : bootstrap mentions '$needle'"; ok=$((ok+1))
  else
    log "FAIL: bootstrap does not reference '$needle'"; fail=$((fail+1))
  fi
done

# 3. Runtime: if kubectl + the cluster are up, verify.
if ! command -v kubectl >/dev/null 2>&1; then
  log "SKIP: kubectl not installed; skipping runtime checks."
elif ! kubectl config get-contexts -o name 2>/dev/null | grep -q "kind-$CLUSTER"; then
  log "SKIP: kind cluster '$CLUSTER' not present; run starter/bootstrap.sh first."
else
  kubectl config use-context "kind-$CLUSTER" >/dev/null 2>&1 || true
  for ns in monitoring logging tracing opentelemetry-operator-system cert-manager apps; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
      log "OK  : namespace $ns exists"; ok=$((ok+1))
    else
      log "WARN: namespace $ns missing"; warn=$((warn+1))
    fi
  done
  # Spot-check CRDs if the Operator is installed.
  if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    log "OK  : CRD servicemonitors.monitoring.coreos.com exists"; ok=$((ok+1))
  else
    log "WARN: CRD servicemonitors.monitoring.coreos.com missing"; warn=$((warn+1))
  fi
  if kubectl get crd opentelemetrycollectors.opentelemetry.io >/dev/null 2>&1; then
    log "OK  : CRD opentelemetrycollectors.opentelemetry.io exists"; ok=$((ok+1))
  else
    log "WARN: CRD opentelemetrycollectors.opentelemetry.io missing"; warn=$((warn+1))
  fi
fi

echo
echo "RESULT: OK=$ok WARN=$warn FAIL=$fail"
if [ "$fail" -gt 0 ]; then
  echo "FAIL: $fail hard check(s) failed."
  exit 1
fi
echo "OK (warnings are informational; runtime checks skipped if cluster not up)."
exit 0
