#!/usr/bin/env bash
# Validate obs-12-01-full-stack-in-kind.
# Structural checks always run; runtime checks only if the kind cluster is up.
#
# Note: deliberately NO 'set -o pipefail' — we use 'grep -q' over pipelines
# where SIGPIPE on early match would be reported as failure by pipefail.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
CLUSTER="${CLUSTER:-obs12}"
RELEASE="${RELEASE:-kps}"
NS_MON="${NS_MON:-monitoring}"
NS_APPS="${NS_APPS:-apps}"

fail=0; warn=0; ok=0
log() { echo "  $*"; }

echo "== Validating obs-12-01 =="

# 1. Structural: starter artifacts present and executable
for f in starter/bootstrap.sh starter/teardown.sh; do
  if [ ! -f "$ACT_DIR/$f" ]; then
    log "FAIL: missing $f"; fail=$((fail+1))
  else
    log "OK  : present $f"; ok=$((ok+1))
    if [ -x "$ACT_DIR/$f" ]; then
      log "OK  : executable $f"; ok=$((ok+1))
    else
      log "WARN: not executable $f (chmod +x)"; warn=$((warn+1))
    fi
  fi
done

# 2. Structural: bootstrap mentions each required stack element
for needle in "kind create cluster" "kube-prometheus-stack" "ServiceMonitor" "grafana_dashboard=1" "prometheus-example-app"; do
  if grep -q "$needle" "$ACT_DIR/starter/bootstrap.sh" 2>/dev/null; then
    log "OK  : bootstrap references '$needle'"; ok=$((ok+1))
  else
    log "FAIL: bootstrap does NOT reference '$needle'"; fail=$((fail+1))
  fi
done

# 3. Pipefail safety sanity: must NOT enable pipefail
if grep -Eq '^[[:space:]]*set[[:space:]]+-[a-z]*o?[[:space:]]+pipefail|^[[:space:]]*set[[:space:]]+-o[[:space:]]+pipefail' "$ACT_DIR/starter/bootstrap.sh" 2>/dev/null; then
  log "FAIL: starter/bootstrap.sh enables pipefail (collides with grep -q pipelines)"
  fail=$((fail+1))
else
  log "OK  : starter/bootstrap.sh does not enable pipefail"; ok=$((ok+1))
fi

# 4. Runtime checks only if tools + cluster are up
if ! command -v kubectl >/dev/null 2>&1; then
  log "SKIP: kubectl not installed; skipping runtime checks."
elif ! kubectl config get-contexts -o name 2>/dev/null | grep -q "kind-$CLUSTER"; then
  log "SKIP: kind cluster '$CLUSTER' not present; run starter/bootstrap.sh first."
else
  kubectl config use-context "kind-$CLUSTER" >/dev/null 2>&1 || true

  # 4.1 Namespaces
  for ns in "$NS_MON" "$NS_APPS"; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
      log "OK  : namespace $ns exists"; ok=$((ok+1))
    else
      log "WARN: namespace $ns missing"; warn=$((warn+1))
    fi
  done

  # 4.2 Operator CRDs
  for crd in servicemonitors.monitoring.coreos.com \
             podmonitors.monitoring.coreos.com \
             prometheuses.monitoring.coreos.com \
             alertmanagers.monitoring.coreos.com \
             prometheusrules.monitoring.coreos.com; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
      log "OK  : CRD $crd exists"; ok=$((ok+1))
    else
      log "WARN: CRD $crd missing"; warn=$((warn+1))
    fi
  done

  # 4.3 ServiceMonitor del estudiante
  if kubectl -n "$NS_APPS" get servicemonitor fastapi >/dev/null 2>&1; then
    log "OK  : ServiceMonitor $NS_APPS/fastapi exists"; ok=$((ok+1))
    rel="$(kubectl -n "$NS_APPS" get servicemonitor fastapi \
            -o jsonpath='{.metadata.labels.release}' 2>/dev/null || echo '')"
    if [ "$rel" = "$RELEASE" ]; then
      log "OK  : ServiceMonitor has release=$RELEASE label"; ok=$((ok+1))
    else
      log "WARN: ServiceMonitor missing release=$RELEASE label (has '$rel')"
      warn=$((warn+1))
    fi
  else
    log "WARN: ServiceMonitor $NS_APPS/fastapi not found"; warn=$((warn+1))
  fi

  # 4.4 Dashboard ConfigMap
  if kubectl -n "$NS_MON" get configmap fastapi-dashboard >/dev/null 2>&1; then
    log "OK  : ConfigMap fastapi-dashboard exists"; ok=$((ok+1))
    lbl="$(kubectl -n "$NS_MON" get configmap fastapi-dashboard \
             -o jsonpath='{.metadata.labels.grafana_dashboard}' 2>/dev/null || echo '')"
    if [ "$lbl" = "1" ]; then
      log "OK  : ConfigMap has grafana_dashboard=1 label"; ok=$((ok+1))
    else
      log "WARN: ConfigMap missing grafana_dashboard=1 label"; warn=$((warn+1))
    fi
  else
    log "WARN: ConfigMap fastapi-dashboard not found"; warn=$((warn+1))
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
