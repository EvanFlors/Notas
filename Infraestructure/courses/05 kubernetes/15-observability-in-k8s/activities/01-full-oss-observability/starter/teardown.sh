#!/usr/bin/env bash
# teardown.sh — remove helm releases, namespaces, and the kind cluster.
set -u

CLUSTER="${CLUSTER:-obs15}"
have() { command -v "$1" >/dev/null 2>&1; }

have helm && {
  helm uninstall kps -n monitoring 2>/dev/null || true
  helm uninstall loki -n logging 2>/dev/null || true
  helm uninstall promtail -n logging 2>/dev/null || true
  helm uninstall otel-op -n opentelemetry-operator-system 2>/dev/null || true
}

have kubectl && {
  kubectl delete ns monitoring logging tracing apps 2>/dev/null || true
  kubectl delete ns opentelemetry-operator-system 2>/dev/null || true
  kubectl delete ns cert-manager 2>/dev/null || true
  kubectl get crd -o name 2>/dev/null | grep -E 'monitoring.coreos.com|opentelemetry.io|cert-manager.io' \
    | xargs -r kubectl delete 2>/dev/null || true
}

have kind && kind delete cluster --name "$CLUSTER" 2>/dev/null || true

rm -rf /tmp/obs15-bootstrap
echo "teardown done."
